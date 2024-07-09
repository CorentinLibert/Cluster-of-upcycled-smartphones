#include "object_detection.h"
#include "tensorflow/lite/kernels/register.h"

#include <iostream>
#include <fstream>
#include <string>
#include <getopt.h>
#include <sys/time.h>
#include "opencv2/imgproc.hpp"
#include <opencv2/imgcodecs.hpp>
#include <opencv2/core/core.hpp>
#include <opencv2/highgui/highgui.hpp> 

using namespace cv;
/**
 * Credits: This code has been inspired by the ones from:
 *  - https://github.com/tensorflow/tensorflow/tree/master/tensorflow/lite/examples/label_image
 *  - https://github.com/ValYouW/crossplatform-tflite-object-detecion/tree/master/native-detector
 */
namespace tflite {
namespace object_detection {
    ObjectDetector::ObjectDetector(Settings s) {
        // Execution time:
        struct timeval start_time, stop_time;
        gettimeofday(&start_time, nullptr);

        // Get labels from file
        labels = new std::vector<string>();
        read_labels(s.labels);

        // Load model
        model = tflite::FlatBufferModel::BuildFromFile(s.tflite_model.c_str());
        if (!model) {
            std::cerr << "ERROR: Failed to build the flat buffer from file" << std::endl;
            exit(EXIT_FAILURE);
        }

        // Build interpreter
        tflite::ops::builtin::BuiltinOpResolver resolver;
        tflite::InterpreterBuilder(*model, resolver)(&interpreter);
        if (!interpreter) {
            std::cerr << "ERROR: Failed to construct interpreter" << std::endl;
            exit(EXIT_FAILURE);
        }

        // Set number of threads
        interpreter->SetNumThreads(s.threads);
        threads = s.threads;

        // Allocate tensor buffers
        if (interpreter->AllocateTensors() != kTfLiteOk) {
            std::cerr << "ERROR: Failed to allocate tensors" << std::endl;
            exit(EXIT_FAILURE);
        }

        // Input tensors
        const std::vector<int> inputs = interpreter->inputs();
        if (inputs.size() != 1) {
            // The image should be the only input (cf. model metadata)
            std::cerr << "ERROR: Detection model graph should have only one input" << std::endl;
            exit(EXIT_FAILURE);
        }
        int input = inputs[0];
        input_tensor = interpreter->tensor(input);

        // Retrieve input type
        input_type = interpreter->tensor(input)->type;

        // Check if the right model (hardcoded) is used (COCO_ssd-mobilenet-v1-tflite) by checking 
        if (input_tensor->dims->data[0] != 1 ||
            input_tensor->dims->data[1] != TFLITE_MODEL_SIZE ||
            input_tensor->dims->data[2] != TFLITE_MODEL_SIZE ||
            input_tensor->dims->data[3] != TFLITE_MODEL_CHANNELS) {
            printf("ERROR: Detection model input as the wrong dimensions, should be 1x%ix%ix%i\n", TFLITE_MODEL_SIZE,
                TFLITE_MODEL_SIZE, TFLITE_MODEL_CHANNELS);
            exit(EXIT_FAILURE);
        }

        // Ouput tensors
        const std::vector<int> outputs = interpreter->outputs();
        if (outputs.size() != 4) {
            std::cerr << "ERROR: Detection model graph should have 4 outputs" << std::endl;
            exit(EXIT_FAILURE);
        }

        // Match output tensors
        output_locations_tensor = interpreter->tensor(outputs[0]);
        output_classes_tensor = interpreter->tensor(outputs[1]);
        output_scores_tensor = interpreter->tensor(outputs[2]);
        num_detections_tensor = interpreter->tensor(outputs[3]);
        
        // Execution time:
        gettimeofday(&stop_time, nullptr);
        int execution_time = (stop_time.tv_sec - start_time.tv_sec) * 1000000;
        execution_time += (stop_time.tv_usec - start_time.tv_usec);
        std::cout << "Load_model," << std::to_string(execution_time) << std::endl;
    }

    void ObjectDetector::run(std::string input_path, std::string output_path, float threshold_score) {
        Mat preprocessed_img = image_preprocessing(input_path);
        std::vector<DetectionResult> *results = new std::vector<DetectionResult>();
        detect(preprocessed_img, results, threshold_score);
        Mat postprocessed_img = image_postprocessing(input_path, results);
        imwrite(output_path ,postprocessed_img);
    }

    void ObjectDetector::read_labels(std::string labels_path) {
        std::ifstream file(labels_path);
        if (!file) {
            std::cerr << "ERROR: Could not read the labels file" << std::endl;
            exit(EXIT_FAILURE);
        }
        labels = new std::vector<string>();
        string line;
        while (std::getline(file, line)) {
            labels->push_back(line);
        }
    }

    Mat ObjectDetector::image_preprocessing(std::string input_path) {
        // Execution time:
        struct timeval start_time, stop_time;
        gettimeofday(&start_time, nullptr);

        Mat src = imread(samples::findFile(input_path), IMREAD_COLOR);    
        if (src.empty()) {
            std::cerr << "ERROR: Could not read the source image" << std::endl;
            exit(EXIT_FAILURE);
        }

        Mat image;
        resize(src, image, Size(TFLITE_MODEL_SIZE, TFLITE_MODEL_SIZE), 0, 0, INTER_AREA);

        // Ensure the input image is in RGB (cf. model metadata)
        int cnls = image.type();
        if (cnls == CV_8UC1) {
            cvtColor(image, image, COLOR_GRAY2RGB); // from 1 channel to 3 (gray to RGB)
        } else if (cnls == CV_8UC4) {
            cvtColor(image, image, COLOR_BGRA2RGB); // from 4 channels to 3 (RGB + alpha to RGB)
        }

        // Execution time:
        gettimeofday(&stop_time, nullptr);
        int execution_time = (stop_time.tv_sec - start_time.tv_sec) * 1000000;
        execution_time += (stop_time.tv_usec - start_time.tv_usec);
        std::cout << "preprocessing," << std::to_string(execution_time) << std::endl;

        return image;
    }

    Mat ObjectDetector::image_postprocessing(std::string input_path, std::vector<DetectionResult> *detection_results) {
        // Execution time:
        struct timeval start_time, stop_time;
        gettimeofday(&start_time, nullptr);

        Mat src = imread(samples::findFile(input_path), IMREAD_COLOR);
        std::vector<DetectionResult>::iterator it;
        int thickness = 2;
        for (it = detection_results->begin(); it != detection_results->end(); it++) {
            // Check that the box is not outside the image and scale up to the source image
            float ymin = std::fmax(0.0f, it->ymin * src.rows);
            float xmin = std::fmax(0.0f, it->xmin * src.cols);
            float ymax = std::fmin(float(src.rows - 1), it->ymax * src.rows);
            float xmax = std::fmin(float(src.cols - 1), it->xmax * src.cols);
            // Draw the box
            rectangle(src, Point(xmin, ymin), Point(xmax, ymax), Scalar(255,0,0), thickness);

            // Retrieve label from index and add score
            std::string label_score = labels->at(it->label) + ": " + std::to_string(it->score);

            // Get the text size to adjust the background box size
            int baseLine;
            Size labelSize = getTextSize(label_score, FONT_HERSHEY_DUPLEX, 0.5, 1, &baseLine);

            int labelX = xmin;
            int labelY = ymin + labelSize.height + baseLine;

            // Draw the background rectangle for the label
            rectangle(src, Point(labelX, labelY), Point(xmin + labelSize.width, ymin), Scalar(255,0,0), FILLED);

            
            // Put the label text on the image
            putText(src, label_score, Point(labelX, labelY), FONT_HERSHEY_DUPLEX, 0.5, Scalar(255, 255, 255), 1);
        }

        // Execution time:
        gettimeofday(&stop_time, nullptr);
        int execution_time = (stop_time.tv_sec - start_time.tv_sec) * 1000000;
        execution_time += (stop_time.tv_usec - start_time.tv_usec);
        std::cout << "postprocessing," << std::to_string(execution_time) << std::endl;

        return src;
    }

    void ObjectDetector::detect(Mat image, std::vector<DetectionResult> *results, float threshold_score) {
        // Execution time:
        struct timeval start_time, stop_time, sub_start_time, sub_stop_time;
        gettimeofday(&start_time, nullptr);
        gettimeofday(&sub_start_time, nullptr);

        // Load image
        // Input type (quantized or not)
        if (input_type == kTfLiteUInt8) {
            memcpy(input_tensor->data.uint8, image.data,
			   sizeof(uchar) * TFLITE_MODEL_SIZE * TFLITE_MODEL_SIZE * TFLITE_MODEL_CHANNELS);
        } 
        else if (input_type == kTfLiteFloat32){
            // Normalize the image based on std and mean (p' = (p-mean)/std)
            Mat fimage;
            image.convertTo(fimage, CV_32FC3, 1 / IMAGE_STD, -IMAGE_MEAN / IMAGE_STD);
            memcpy(input_tensor->data.f, fimage.data,
			   sizeof(float) * TFLITE_MODEL_SIZE * TFLITE_MODEL_SIZE * TFLITE_MODEL_CHANNELS);
        } 
        else {
            std::cerr << "ERROR: Wrong interpreter input type <" << input_type << "> (<kTfLiteUInt8> or <kTfLiteFloat32> expected)" << std::endl;
            exit(EXIT_FAILURE);
        }
        // Execution time:
        gettimeofday(&sub_stop_time, nullptr);
        int execution_time = (sub_stop_time.tv_sec - sub_start_time.tv_sec) * 1000000;
        execution_time += (sub_stop_time.tv_usec - sub_start_time.tv_usec);
        std::cout << "Load image," << std::to_string(execution_time) << std::endl;
        gettimeofday(&sub_start_time, nullptr);

        // Invoke interpreter
        if (interpreter->Invoke() != kTfLiteOk) {
		    std::cerr << "ERROR: Failed to invoke tflite" << std::endl;
		    exit(EXIT_FAILURE);
        }

        gettimeofday(&sub_stop_time, nullptr);
        execution_time = (sub_stop_time.tv_sec - sub_start_time.tv_sec) * 1000000;
        execution_time += (sub_stop_time.tv_usec - sub_start_time.tv_usec);
        std::cout << "Invoke interpreter," << std::to_string(execution_time) << std::endl;
        gettimeofday(&sub_start_time, nullptr);

        // Retrieve results from tensors
        const float *detection_locations = output_locations_tensor->data.f;
        const float *detection_classes = output_classes_tensor->data.f;
        const float *detection_scores = output_scores_tensor->data.f;
        const int num_detections = (int) *num_detections_tensor->data.f;
        results->clear();

        for (int i = 0; i < num_detections; i++) {
            if (detection_scores[i] >= threshold_score) {
                DetectionResult detection;
                detection.label = (int) detection_classes[i];
                detection.score = detection_scores[i];
                detection.ymin = detection_locations[4 * i];
                detection.xmin = detection_locations[4 * i + 1];
                detection.ymax = detection_locations[4 * i + 2];
                detection.xmax = detection_locations[4 * i + 3];
                results->push_back(detection);
            }
        }

        gettimeofday(&sub_stop_time, nullptr);
        execution_time = (sub_stop_time.tv_sec - sub_start_time.tv_sec) * 1000000;
        execution_time += (sub_stop_time.tv_usec - sub_start_time.tv_usec);
        std::cout << "Retrieve results," << std::to_string(execution_time) << std::endl;

        // Execution time:
        gettimeofday(&stop_time, nullptr);
        execution_time = (stop_time.tv_sec - start_time.tv_sec) * 1000000;
        execution_time += (stop_time.tv_usec - start_time.tv_usec);
        std::cout << "detection," << std::to_string(execution_time) << std::endl;
    }

    void usage() {
        std::cout 
            << "Usage: object_detection\n"
            << "\t--image, -i: image_name.jpg\n"
            << "\t--tflite_model, -m: model_name.tflite\n"
            << "\t--labels, -l: labels of the model (.txt)\n"
            << "\t--output_file, -o: output_file.jpg\n"
            << "\t--threshold_score, -s: threshold of the score (between 0 and 1)\n"
            << "\t--threads, -t: number of threads\n"
            << "\t--help, -h: Print this help message\n";      
    }

    int Main(int argc, char **argv) {
        Settings s;

        int c;
        while(true) {
            static struct option long_options[] = {
                {"image", required_argument, nullptr, 'i'},
                {"labels", required_argument, nullptr, 'l'},
                {"tflite_model", required_argument, nullptr, 'm'},
                {"output_file", required_argument, nullptr, 'o'},
                {"threshold_score", required_argument, nullptr, 's'},
                {"threads", required_argument, nullptr, 't'},
                {"help", required_argument, nullptr, 'h'},
                {nullptr, 0, nullptr, 0}};
            
            int option_index = 0;
            c = getopt_long(argc, argv, "i:l:m:o:s:t:h", long_options, &option_index);

            if (c == -1) break;

            switch (c)
            {
            case 'i':
                s.image = optarg;
                break;
            case 'l':
                s.labels = optarg;
                break;
            case 'm':
                s.tflite_model = optarg;
                break;
            case 'o':
                s.output_file = optarg;
                break;
            case 's':
                s.threshold_score = strtof(optarg, nullptr);;
                break;
            case 't':
                s.threads = strtol(optarg, nullptr, 10);
                break;
            case 'h':
                usage();
                exit(EXIT_SUCCESS);
            case '?':
                usage();
                exit(EXIT_FAILURE);
            default:
                exit(EXIT_FAILURE);
            }
        }

        ObjectDetector od = ObjectDetector(s);
        od.run(s.image, s.output_file, s.threshold_score);
        
        return 0;
    }
} // namespace tflite 
} // namespace object_detection

int main(int argc, char **argv) {
    return tflite::object_detection::Main(argc, argv);
}