/* Copyright 2017 The TensorFlow Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
==============================================================================*/

#include "tensorflow/lite/examples/label_image_crow_webserver/label_image.h"

#include <fcntl.h>      // NOLINT(build/include_order)
#include <getopt.h>     // NOLINT(build/include_order)
#include <sys/time.h>   // NOLINT(build/include_order)
#include <sys/types.h>  // NOLINT(build/include_order)
#include <sys/uio.h>    // NOLINT(build/include_order)
#include <unistd.h>     // NOLINT(build/include_order)

#include <cstdarg>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <map>
#include <memory>
#include <sstream>
#include <string>
#include <unordered_set>
#include <utility>
#include <vector>
#include <nlohmann/json.hpp>

#include "absl/memory/memory.h"
#include "tensorflow/lite/examples/label_image_crow_webserver/bitmap_helpers.h"
#include "tensorflow/lite/examples/label_image_crow_webserver/get_top_n.h"
#include "tensorflow/lite/examples/label_image_crow_webserver/log.h"
#include "tensorflow/lite/kernels/register.h"
#include "tensorflow/lite/optional_debug_tools.h"
#include "tensorflow/lite/profiling/profiler.h"
#include "tensorflow/lite/string_util.h"
#include "tensorflow/lite/tools/command_line_flags.h"
#include "tensorflow/lite/tools/delegates/delegate_provider.h"
#include "crow.h"

using json = nlohmann::json;

namespace tflite {
namespace label_image {

double get_us(struct timeval t) { return (t.tv_sec * 1000000 + t.tv_usec); }

using TfLiteDelegatePtr = tflite::Interpreter::TfLiteDelegatePtr;
using ProvidedDelegateList = tflite::tools::ProvidedDelegateList;

class DelegateProviders {
 public:
  DelegateProviders() : delegate_list_util_(&params_) {
    delegate_list_util_.AddAllDelegateParams();
    delegate_list_util_.AppendCmdlineFlags(flags_);

    // Remove the "help" flag to avoid printing "--help=false"
    params_.RemoveParam("help");
    delegate_list_util_.RemoveCmdlineFlag(flags_, "help");
  }

  // Initialize delegate-related parameters from parsing command line arguments,
  // and remove the matching arguments from (*argc, argv). Returns true if all
  // recognized arg values are parsed correctly.
  bool InitFromCmdlineArgs(int* argc, const char** argv) {
    // Note if '--help' is in argv, the Flags::Parse return false,
    // see the return expression in Flags::Parse.
    return Flags::Parse(argc, argv, flags_);
  }

  // According to passed-in settings `s`, this function sets corresponding
  // parameters that are defined by various delegate execution providers. See
  // lite/tools/delegates/README.md for the full list of parameters defined.
  void MergeSettingsIntoParams(const Settings& s) {
    // Parse settings related to GPU delegate.
    // Note that GPU delegate does support OpenCL. 'gl_backend' was introduced
    // when the GPU delegate only supports OpenGL. Therefore, we consider
    // setting 'gl_backend' to true means using the GPU delegate.
    if (s.gl_backend) {
      if (!params_.HasParam("use_gpu")) {
        LOG(WARN) << "GPU delegate execution provider isn't linked or GPU "
                     "delegate isn't supported on the platform!";
      } else {
        params_.Set<bool>("use_gpu", true);
        // The parameter "gpu_inference_for_sustained_speed" isn't available for
        // iOS devices.
        if (params_.HasParam("gpu_inference_for_sustained_speed")) {
          params_.Set<bool>("gpu_inference_for_sustained_speed", true);
        }
        params_.Set<bool>("gpu_precision_loss_allowed", s.allow_fp16);
      }
    }

    // Parse settings related to NNAPI delegate.
    if (s.accel) {
      if (!params_.HasParam("use_nnapi")) {
        LOG(WARN) << "NNAPI delegate execution provider isn't linked or NNAPI "
                     "delegate isn't supported on the platform!";
      } else {
        params_.Set<bool>("use_nnapi", true);
        params_.Set<bool>("nnapi_allow_fp16", s.allow_fp16);
      }
    }

    // Parse settings related to Hexagon delegate.
    if (s.hexagon_delegate) {
      if (!params_.HasParam("use_hexagon")) {
        LOG(WARN) << "Hexagon delegate execution provider isn't linked or "
                     "Hexagon delegate isn't supported on the platform!";
      } else {
        params_.Set<bool>("use_hexagon", true);
        params_.Set<bool>("hexagon_profiling", s.profiling);
      }
    }

    // Parse settings related to XNNPACK delegate.
    if (s.xnnpack_delegate) {
      if (!params_.HasParam("use_xnnpack")) {
        LOG(WARN) << "XNNPACK delegate execution provider isn't linked or "
                     "XNNPACK delegate isn't supported on the platform!";
      } else {
        params_.Set<bool>("use_xnnpack", true);
        params_.Set<int32_t>("num_threads", s.number_of_threads);
      }
    }
  }

  // Create a list of TfLite delegates based on what have been initialized (i.e.
  // 'params_').
  std::vector<ProvidedDelegateList::ProvidedDelegate> CreateAllDelegates()
      const {
    return delegate_list_util_.CreateAllRankedDelegates();
  }

  std::string GetHelpMessage(const std::string& cmdline) const {
    return Flags::Usage(cmdline, flags_);
  }

 private:
  // Contain delegate-related parameters that are initialized from command-line
  // flags.
  tflite::tools::ToolParams params_;

  // A helper to create TfLite delegates.
  ProvidedDelegateList delegate_list_util_;

  // Contains valid flags
  std::vector<tflite::Flag> flags_;
};

// Takes a file name, and loads a list of labels from it, one per line, and
// returns a vector of the strings. It pads with empty strings so the length
// of the result is a multiple of 16, because our model expects that.
TfLiteStatus ReadLabelsFile(const string& file_name,
                            std::vector<string>* result,
                            size_t* found_label_count) {
  std::ifstream file(file_name);
  if (!file) {
    LOG(ERROR) << "Labels file " << file_name << " not found";
    return kTfLiteError;
  }
  result->clear();
  string line;
  while (std::getline(file, line)) {
    result->push_back(line);
  }
  *found_label_count = result->size();
  const int padding = 16;
  while (result->size() % padding) {
    result->emplace_back();
  }
  return kTfLiteOk;
}

void PrintProfilingInfo(const profiling::ProfileEvent* e,
                        uint32_t subgraph_index, uint32_t op_index,
                        TfLiteRegistration registration) {
  // output something like
  // time (ms) , Node xxx, OpCode xxx, symbolic name
  //      5.352, Node   5, OpCode   4, DEPTHWISE_CONV_2D

  LOG(INFO) << std::fixed << std::setw(10) << std::setprecision(3)
            << (e->elapsed_time) / 1000.0 << ", Subgraph " << std::setw(3)
            << std::setprecision(3) << subgraph_index << ", Node "
            << std::setw(3) << std::setprecision(3) << op_index << ", OpCode "
            << std::setw(3) << std::setprecision(3) << registration.builtin_code
            << ", "
            << EnumNameBuiltinOperator(
                   static_cast<BuiltinOperator>(registration.builtin_code));
}

void SetupInterpreter(Settings* settings, const DelegateProviders& delegate_providers) {
  // Execution time
  struct timeval start_time, stop_time, g_start_time, g_stop_time;
  if(settings->execution_duration) {
    gettimeofday(&g_start_time, nullptr);
    gettimeofday(&start_time, nullptr);
  }

  if (!settings->model_name.c_str()) {
    LOG(ERROR) << "no model file name";
    exit(-1);
  }

  settings->model = tflite::FlatBufferModel::BuildFromFile(settings->model_name.c_str());
  if (!settings->model) {
    LOG(ERROR) << "Failed to mmap model " << settings->model_name;
    exit(-1);
  }

  LOG(INFO) << "Loaded model " << settings->model_name;
  settings->model->error_reporter();
  LOG(INFO) << "resolved reporter";

  // Exexcution Time
  if(settings->execution_duration) {
    gettimeofday(&stop_time, nullptr);
    LOG(TIME) << "Load Model: "
              << (get_us(stop_time) - get_us(start_time))
              << " us";
    gettimeofday(&start_time, nullptr);
  }

  tflite::ops::builtin::BuiltinOpResolver resolver;
  
  tflite::InterpreterBuilder(*settings->model, resolver)(&settings->interpreter);
  if (!settings->interpreter) {
    LOG(ERROR) << "Failed to construct interpreter";
    exit(-1);
  }

  settings->interpreter->SetAllowFp16PrecisionForFp32(settings->allow_fp16);

  if (settings->verbose) {
    LOG(INFO) << "tensors size: " << settings->interpreter->tensors_size();
    LOG(INFO) << "nodes size: " << settings->interpreter->nodes_size();
    LOG(INFO) << "inputs: " << settings->interpreter->inputs().size();
    LOG(INFO) << "input(0) name: " << settings->interpreter->GetInputName(0);

    int t_size = settings->interpreter->tensors_size();
    for (int i = 0; i < t_size; i++) {
      if (settings->interpreter->tensor(i)->name)
        LOG(INFO) << i << ": " << settings->interpreter->tensor(i)->name << ", "
                  << settings->interpreter->tensor(i)->bytes << ", "
                  << settings->interpreter->tensor(i)->type << ", "
                  << settings->interpreter->tensor(i)->params.scale << ", "
                  << settings->interpreter->tensor(i)->params.zero_point;
    }
  }

  if (settings->number_of_threads != -1) {
    settings->interpreter->SetNumThreads(settings->number_of_threads);
  }

  int input = settings->interpreter->inputs()[0];
  if (settings->verbose) LOG(INFO) << "input: " << input;

  const std::vector<int> inputs = settings->interpreter->inputs();
  const std::vector<int> outputs = settings->interpreter->outputs();

  if (settings->verbose) {
    LOG(INFO) << "number of inputs: " << inputs.size();
    LOG(INFO) << "number of outputs: " << outputs.size();
  }

  if (settings->interpreter->AllocateTensors() != kTfLiteOk) {
    LOG(ERROR) << "Failed to allocate tensors!";
    exit(-1);
  }

  // Exexcution Time
  if(settings->execution_duration) {
    gettimeofday(&stop_time, nullptr);
    LOG(TIME) << "Build Interpreter: "
              << (get_us(stop_time) - get_us(start_time))
              << " us";
    gettimeofday(&start_time, nullptr);
  }

  settings->profiler = std::make_unique<profiling::Profiler>(
      settings->max_profiling_buffer_entries);
  settings->interpreter->SetProfiler(settings->profiler.get());

  auto delegates = delegate_providers.CreateAllDelegates();
  for (auto& delegate : delegates) {
    const auto delegate_name = delegate.provider->GetName();
    if (settings->interpreter->ModifyGraphWithDelegate(std::move(delegate.delegate)) !=
        kTfLiteOk) {
      LOG(ERROR) << "Failed to apply " << delegate_name << " delegate.";
      exit(-1);
    } else {
      LOG(INFO) << "Applied " << delegate_name << " delegate.";
    }
  }

  // Exexcution Time
  if(settings->execution_duration) {
    gettimeofday(&stop_time, nullptr);
    LOG(TIME) << "Build profiler and delegation: "
              << (get_us(stop_time) - get_us(start_time))
              << " us";
    gettimeofday(&g_stop_time, nullptr);
    LOG(TIME) << "Setup Interpreter (global time): "
              << (get_us(g_stop_time) - get_us(g_start_time))
              << " us";
  }
}

std::string RunInference(Settings* settings, const DelegateProviders& delegate_providers, const std::string& input_image) {
  // Execution time
  struct timeval start_time, stop_time, g_start_time, g_stop_time;
  if(settings->execution_duration) {
    gettimeofday(&g_start_time, nullptr);
    gettimeofday(&start_time, nullptr);
  }

  int image_width = 224;
  int image_height = 224;
  int image_channels = 3;
  std::vector<uint8_t> in = read_bmp(input_image, &image_width,
                                     &image_height, &image_channels, settings);

  if(settings->execution_duration) {
    gettimeofday(&stop_time, nullptr);
    LOG(TIME) << "Read BMP: "
              << (get_us(stop_time) - get_us(start_time))
              << " us";
    gettimeofday(&start_time, nullptr);
  }

  int input = settings->interpreter->inputs()[0];
  if (settings->verbose) LOG(INFO) << "input: " << input;

  if (settings->verbose) PrintInterpreterState(settings->interpreter.get());

  // get input dimension from the input tensor metadata
  // assuming one input only
  TfLiteIntArray* dims = settings->interpreter->tensor(input)->dims;
  int wanted_height = dims->data[1];
  int wanted_width = dims->data[2];
  int wanted_channels = dims->data[3];

  settings->input_type = settings->interpreter->tensor(input)->type;
  switch (settings->input_type) {
    case kTfLiteFloat32:
      resize<float>(settings->interpreter->typed_tensor<float>(input), in.data(),
                    image_height, image_width, image_channels, wanted_height,
                    wanted_width, wanted_channels, settings);
      break;
    case kTfLiteInt8:
      resize<int8_t>(settings->interpreter->typed_tensor<int8_t>(input), in.data(),
                     image_height, image_width, image_channels, wanted_height,
                     wanted_width, wanted_channels, settings);
      break;
    case kTfLiteUInt8:
      resize<uint8_t>(settings->interpreter->typed_tensor<uint8_t>(input), in.data(),
                      image_height, image_width, image_channels, wanted_height,
                      wanted_width, wanted_channels, settings);
      break;
    default:
      LOG(ERROR) << "cannot handle input type "
                 << settings->interpreter->tensor(input)->type << " yet";
      exit(-1);
  }

  if(settings->execution_duration) {
    gettimeofday(&stop_time, nullptr);
    LOG(TIME) << "Resize image and set input: "
              << (get_us(stop_time) - get_us(start_time))
              << " us";
    gettimeofday(&start_time, nullptr);
  }

  if (settings->profiling) settings->profiler->StartProfiling();
  for (int i = 0; i < settings->number_of_warmup_runs; i++) {
    if (settings->interpreter->Invoke() != kTfLiteOk) {
      LOG(ERROR) << "Failed to invoke tflite!";
      exit(-1);
    }
  }

  if(settings->execution_duration) {
    gettimeofday(&stop_time, nullptr);
    LOG(TIME) << "Warm-up: "
              << (get_us(stop_time) - get_us(start_time))
              << " us";
    gettimeofday(&start_time, nullptr);
  }

  for (int i = 0; i < settings->loop_count; i++) {
    if (settings->interpreter->Invoke() != kTfLiteOk) {
      LOG(ERROR) << "Failed to invoke tflite!";
      exit(-1);
    }
  }

  if(settings->execution_duration) {
    gettimeofday(&stop_time, nullptr);
    LOG(TIME) << "Invokation total: "
              << (get_us(stop_time) - get_us(start_time))
              << " us";
    LOG(TIME) << "Invokation average: "
              << (get_us(stop_time) - get_us(start_time)) /
                    (settings->loop_count)
              << " us";
    gettimeofday(&start_time, nullptr);
  }

  if (settings->profiling) {
    settings->profiler->StopProfiling();
    auto profile_events = settings->profiler->GetProfileEvents();
    for (int i = 0; i < profile_events.size(); i++) {
      auto subgraph_index = profile_events[i]->extra_event_metadata;
      auto op_index = profile_events[i]->event_metadata;
      const auto subgraph = settings->interpreter->subgraph(subgraph_index);
      const auto node_and_registration =
          subgraph->node_and_registration(op_index);
      const TfLiteRegistration registration = node_and_registration->second;
      PrintProfilingInfo(profile_events[i], subgraph_index, op_index,
                         registration);
    }
  }

  if(settings->execution_duration) {
    gettimeofday(&stop_time, nullptr);
    LOG(TIME) << "Profiling: "
              << (get_us(stop_time) - get_us(start_time))
              << " us";
    gettimeofday(&start_time, nullptr);
  }

  const float threshold = 0.001f;

  std::vector<std::pair<float, int>> top_results;

  int output = settings->interpreter->outputs()[0];
  TfLiteIntArray* output_dims = settings->interpreter->tensor(output)->dims;
  // assume output dims to be something like (1, 1, ... ,size)
  auto output_size = output_dims->data[output_dims->size - 1];
  switch (settings->interpreter->tensor(output)->type) {
    case kTfLiteFloat32:
      get_top_n<float>(settings->interpreter->typed_output_tensor<float>(0), output_size,
                       settings->number_of_results, threshold, &top_results,
                       settings->input_type);
      break;
    case kTfLiteInt8:
      get_top_n<int8_t>(settings->interpreter->typed_output_tensor<int8_t>(0),
                        output_size, settings->number_of_results, threshold,
                        &top_results, settings->input_type);
      break;
    case kTfLiteUInt8:
      get_top_n<uint8_t>(settings->interpreter->typed_output_tensor<uint8_t>(0),
                         output_size, settings->number_of_results, threshold,
                         &top_results, settings->input_type);
      break;
    default:
      LOG(ERROR) << "cannot handle output type "
                 << settings->interpreter->tensor(output)->type << " yet";
      exit(-1);
  }

  if(settings->execution_duration) {
    gettimeofday(&stop_time, nullptr);
    LOG(TIME) << "Get ouputs: "
              << (get_us(stop_time) - get_us(start_time))
              << " us";
    gettimeofday(&start_time, nullptr);
  }

  std::vector<string> labels;
  size_t label_count;

  if (ReadLabelsFile(settings->labels_file_name, &labels, &label_count) !=
      kTfLiteOk)
    exit(-1);

  if(settings->execution_duration) {
    gettimeofday(&stop_time, nullptr);
    LOG(TIME) << "Read Labels: "
              << (get_us(stop_time) - get_us(start_time))
              << " us";
    gettimeofday(&start_time, nullptr);
  }

  std::string results;
  for (const auto& result : top_results) {
    const float confidence = result.first;
    const int index = result.second;
    results += std::to_string(confidence) + ": " + std::to_string(index) + " " + labels[index] + "\n";
  }

  // Destory the interpreter earlier than delegates objects.
  settings->interpreter.reset();
  if(settings->execution_duration) {
    gettimeofday(&g_stop_time, nullptr);
    LOG(TIME) << "Run Inference (global time): "
              << (get_us(g_stop_time) - get_us(g_start_time))
              << " us";
  }

  return results;
}

/**
 * Return a timestamp of the current local time in the format %Y%m%dT%H%M%s%ms%us (where ms and us stand for milliseconds and microseconds). 
 */
std::string getTimestamp() {
    auto now = std::chrono::system_clock::now();
    std::time_t t_c = std::chrono::system_clock::to_time_t(now);
    std::tm tm = *std::localtime(&t_c);
    
    auto duration = now.time_since_epoch();
    auto millis = std::chrono::duration_cast<std::chrono::milliseconds>(duration) % 1000;
    auto micros = std::chrono::duration_cast<std::chrono::microseconds>(duration) % 1000;

    std::ostringstream oss;
    oss << std::put_time(&tm, "%Y%m%dT%H%M%S")
        << std::setw(3) << std::setfill('0') << millis.count()
        << std::setw(3) << std::setfill('0') << micros.count();
    
    return oss.str();
}

/**
 * Handle the image from a HTTP request by saving it under the name specify in the crow_settings to which a timestamp is added.
 * @param req A pointer to a crow request represention the HTTP request.
 * @param crow_settings A pointer to the crow settings, containing the basename of the image.
 * @param output_image A point to a string that should contain the name the saved image (basename + timestamp).
 * @return A crow response, corresponsing to the HTTP response.
 */
crow::response handle_image(const crow::request& req, CrowSettings *crow_settings, std::string& output_image) {
  struct timeval start_time, stop_time;
  if(crow_settings->execution_duration)
    gettimeofday(&start_time, nullptr);

  // Check if request's content-type is multipart
  const std::string& req_content_type = req.get_header_value("Content-Type");
  const std::string& multipart_content_type = "multipart/form-data";
  // This version of C++ does not support "contains()"
  if (req_content_type.find(multipart_content_type) == std::string::npos) {
    return crow::response(crow::status::BAD_REQUEST, "Invalid content type: multipart/form-data expected.\n");
  }

  // Check if the request contains an image
  crow::multipart::message msg(req);
  crow::multipart::part image_part = msg.get_part_by_name("image");
  std::string img_content_type = image_part.get_header_object("Content-Type").value;
  const std::string& octet_stream_content_type = "application/octet-stream";
  // This version of C++ does not support "contains()"
  if (img_content_type.find(octet_stream_content_type) == std::string::npos) {
    return crow::response(crow::status::BAD_REQUEST, "Missing image data.\n");
  }

  // Save the bitmap image in local
  std::string image_data = image_part.body;
  output_image = crow_settings->input_file + "_" + getTimestamp();
  std::ofstream out(output_image, std::ios::out | std::ios::binary);
  if (!out.is_open()) {
    return crow::response(crow::status::INTERNAL_SERVER_ERROR, "Could not save the image: output file not opening.\n");
  }
  out.write(image_data.c_str(), image_data.length());
  out.close();

  if (crow_settings->execution_duration) {
    gettimeofday(&stop_time, nullptr);
    LOG(TIME) << "crow,handling,"
              << (get_us(stop_time) - get_us(start_time))
              << " us";
  }

  return crow::response(crow::status::OK);
}

crow::response process_image(CrowSettings *crow_settings, Settings *tflite_settings, DelegateProviders *delegate_providers, std::string& image) {
  struct timeval start_time, stop_time;
  if(crow_settings->execution_duration)
    gettimeofday(&start_time, nullptr);
    
  std::string results = RunInference(tflite_settings, *delegate_providers, image);

  if (crow_settings->execution_duration) {
    gettimeofday(&stop_time, nullptr);
    LOG(TIME) << "crow,processing,"
              << (get_us(stop_time) - get_us(start_time))
              << " us";
  }

  return crow::response(crow::status::OK, results);
}

crow::response label_image(CrowSettings *crow_settings, Settings *tflite_settings, DelegateProviders *delegate_providers, const crow::request& req) {
  std::string saved_image;
  crow::response res = handle_image(req, crow_settings, saved_image);
  if (res.code != 200) { return res; }
  res = process_image(crow_settings, tflite_settings, delegate_providers, saved_image);
  if (res.code != 200) { return res; }
  return res;
}

void display_usage() {
    std::cout 
        << "Usage: crow_webserver <flags>\n"
        << "Flags:\n"
        << "\t--configfile, -c: the path to the json config file\n"
        << "\t--help, -h: display this usage message\n";
}


void parse_configfile_to_settings(const std::string& filename, CrowSettings *crow_settings, Settings *tflite_settings) {
    std::ifstream file(filename);
    json config;
    file >> config;

    // Setup server settings
    if (config.contains("input_file")) crow_settings->input_file = config["input_file"];
    if (config.contains("output_file")) crow_settings->output_file = config["output_file"];
    if (config.contains("port")) crow_settings->port = config["port"];
    if (config.contains("threads")) crow_settings->threads = config["threads"];
    if (config.contains("execution_duration")) crow_settings->execution_duration = config["execution_duration"];

    // Setup tflite settings
    if (config.contains("tflite")) {
        auto tflite_config = config["tflite"];
        if (tflite_config.contains("accelerated")) tflite_settings->accel = tflite_config["accelerated"];
        if (tflite_config.contains("allow_fp16")) tflite_settings->allow_fp16 = tflite_config["allow_fp16"];
        if (tflite_config.contains("count")) tflite_settings->loop_count = tflite_config["count"];
        if (tflite_config.contains("verbose")) tflite_settings->verbose = tflite_config["verbose"];
        if (tflite_config.contains("image")) tflite_settings->input_bmp_name = tflite_config["image"];
        if (tflite_config.contains("labels")) tflite_settings->labels_file_name = tflite_config["labels"];
        if (tflite_config.contains("tflite_model")) tflite_settings->model_name = tflite_config["tflite_model"];
        if (tflite_config.contains("threads")) tflite_settings->number_of_threads = tflite_config["threads"];
        if (tflite_config.contains("input_mean")) tflite_settings->input_mean = tflite_config["input_mean"];
        if (tflite_config.contains("input_std")) tflite_settings->input_std = tflite_config["input_std"];
        if (tflite_config.contains("max_profiling_buffer_entries")) tflite_settings->max_profiling_buffer_entries = tflite_config["max_profiling_buffer_entries"];
        if (tflite_config.contains("warmup_runs")) tflite_settings->number_of_warmup_runs = tflite_config["warmup_runs"];
        if (tflite_config.contains("gl_backend")) tflite_settings->gl_backend = tflite_config["gl_backend"];
        if (tflite_config.contains("hexagon_delegate")) tflite_settings->hexagon_delegate = tflite_config["hexagon_delegate"];
        if (tflite_config.contains("xnnpack_delegate")) tflite_settings->xnnpack_delegate = tflite_config["xnnpack_delegate"];
        if (tflite_config.contains("execution_duration")) tflite_settings->execution_duration = tflite_config["execution_duration"];
    }
}


std::string parsing_arguments(int argc, char **argv) {
    std::string configfile = "config.json";
    int c;
    while (true) {
        static struct option long_options[] = {
            {"configfile", required_argument, nullptr, 'c'},
            {"help", no_argument, nullptr, 'h'},
            {nullptr, 0, nullptr, 0}};
        
            /* getopt_long stores the option index here. */
        int option_index = 0;

        c = getopt_long(argc, argv, "c:h",
                        long_options, &option_index);

        /* Detect the end of the options. */
        if (c == -1) break;

        switch (c) {
            case 'c':
                configfile = optarg;
                break;
            case 'h':
            case '?':
                /* getopt_long already printed an error message. */
                display_usage();
                exit(-1);
            default:
                exit(-1);
        }
    }
    return configfile;
}

int Main(int argc, char **argv) {
    // Parsing arguments
    CrowSettings crow_settings;
    Settings tflite_settings;
    DelegateProviders delegate_providers;

    std::string configfile = parsing_arguments(argc, argv);
    parse_configfile_to_settings(configfile, &crow_settings, &tflite_settings);
    delegate_providers.MergeSettingsIntoParams(tflite_settings);

    SetupInterpreter(&tflite_settings, delegate_providers);

    // Crow app
    crow::SimpleApp app;

    CROW_ROUTE(app, "/")([](){
        return "Hello world";
    });

    CROW_ROUTE(app, "/label_image").methods(crow::HTTPMethod::POST)([&crow_settings, &tflite_settings, &delegate_providers](const crow::request& req){
        return label_image(&crow_settings, &tflite_settings, &delegate_providers, req);
    });

    // Set the port, set the app to run on multiple threads, and run the app
    app.port(crow_settings.port).concurrency(crow_settings.threads).run();
    return 0;
}


}  // namespace label_image
}  // namespace tflite

int main(int argc, char** argv) {
  return tflite::label_image::Main(argc, argv);
}
