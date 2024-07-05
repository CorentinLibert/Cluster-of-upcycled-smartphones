#include "object_detection.h"
#include "include/tensorflow/lite/kernels/register.h"

#include <iostream>
#include <fstream>
#include <string>
#include <getopt.h> 
// #include "opencv2/imgproc.hpp"

/**
 * Credits: This code has been inspired by the ones from:
 *  - https://github.com/tensorflow/tensorflow/tree/master/tensorflow/lite/examples/label_image
 *  - https://github.com/ValYouW/crossplatform-tflite-object-detecion/tree/master/native-detector
 */
namespace tflite {
namespace object_detection {
    ObjectDetector::ObjectDetector(Settings s) {
        // // Check if tfliteModel is provided
        // if (tfliteModel != nullptr) {
        //     std::cerr << "ERROR: No tflite model provided";
        //     exit(EXIT_FAILURE);
        // }

        // // Check if labels path provided
        // if (!labels_path) {
        //     std::cerr << "ERROR: No path to the labels file provided";
        //     exit(EXIT_FAILURE);
        // }

        // Get labels from file
        labels = new std::vector<string>();
        read_labels(s.labels);

        // Load model
        model = tflite::FlatBufferModel::BuildFromFile(s.tflite_model.c_str());
        if (!model) {
            std::cerr << "ERROR: Failed to build the flat buffer from file ";
            exit(EXIT_FAILURE);
        }

        // Build interpreter
        tflite::ops::builtin::BuiltinOpResolver resolver;
        tflite::InterpreterBuilder(*model, resolver)(&interpreter);
        if (!interpreter) {
            std::cerr << "ERROR: Failed to construct interpreter";
            exit(EXIT_FAILURE);
        }

        // TODO add a paramter "number of threads"
        // Set number of threads
        interpreter->SetNumThreads(s.threads);

        // Allocate tensor buffers
        if (interpreter->AllocateTensors() != kTfLiteOk) {
            printf("ERROR: Failed to allocate tensors");
            exit(EXIT_FAILURE);
        }

        // Input tensors
        const std::vector<int> inputs = interpreter->inputs();
        if (inputs.size() != 1) {
            // The image should be the only input (cf. model metadata)
            std::cerr << "ERROR: Detection model graph should have only one input";
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
            printf("ERROR: Detection model input as the wrong dimensions, should be 1x%ix%ix%i", TFLITE_MODEL_SIZE,
                TFLITE_MODEL_SIZE, TFLITE_MODEL_CHANNELS);
            exit(EXIT_FAILURE);
        }

        // Ouput tensors
        const std::vector<int> outputs = interpreter->outputs();
        if (outputs.size() != 4) {
            std::cerr << "ERROR: Detection model graph should have 4 outputs";
            exit(EXIT_FAILURE);
        }

        // Match output tensors
        output_locations_tensor = interpreter->tensor(outputs[0]);
        output_classes_tensor = interpreter->tensor(outputs[1]);
        output_scores_tensor = interpreter->tensor(outputs[2]);
        num_detections_tensor = interpreter->tensor(outputs[3]);
    }

    void ObjectDetector::run(std::string input_path, std::string output_path) {
        Map preprocessed_img = image_preprocessing(input_path);std::vector<DetectionResult> *results = new std::vector<DetectionResult>();
        detect(preprocessed_img, results);
        Map postprocessed_img = image_postprocessing(input_path, output_path, results);
        imwrite(output_path ,postprocessed_img);
    }

    void read_labels(std::string labels_path) {
        std::ifstream file(labels_path);
        if (!file) {
            std::cerr << "ERROR: Could not read the labels file";
            exit(EXIT_FAILURE);
        }
        labels->clear();
        string line;
        while (std::getline(file, line)) {
            labels->push_back(line);
        }
    }

    Map image_preprocessing(std::string input_path) {
        Mat src = imread(samples::findFile(input_path), IMREAD_COLOR);    
        if (src.empty()) {
            std::cerr << "ERROR: Could not read the source image";
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

        return image;
    }

    Map image_postprocessing(std::string input_path, std::vector<DetectionResult> *detection_results) {
        Mat src = imread(samples::findFile(filename), IMREAD_COLOR);
        std::vector<DetectionResult>::iterator it;
        for (it = detection_results->begin(); it != detection_results->end(); it++) {
            // Check that the box is not outside the image and scale up to the source image
            float ymin = std::fmax(0.0f, it->ymin * src.rows);
            float xmin = std::fmax(0.0f, it->xmin * src.cols);
            float ymax = std::fmin(float(src.rows - 1), it->ymax * src.rows);
            float xmax = std::fmin(float(src.cols - 1), it->xmax * src.cols);
            // Draw the box
            rectange(src, Point(xmin, ymin), Point(xmax, ymax), color(255,0,0), thickness=1);

            // Retrieve label from index and add score
            std::string label_score = labels->at(it->label) + ": " + std::to_string(it->score);

            // Get the text size to adjust the background box size
            int baseLine;
            Size labelSize = cv::getTextSize(label_score, FONT_HERSHEY_SIMPLEX, 0.5, 1, &baseLine);

            int labelX = xmin;
            int labelY = ymin - labelSize.height - baseLine;

            // Draw the background rectangle for the label
            rectangle(image, Point(labelX, labelY), Point(xmin + labelSize.width, ymin), color(255,0,0), FILLED);

            
            // Put the label text on the image
            putText(image, labelText, Point(labelX, labelY), FONT_HERSHEY_SIMPLEX, 0.5, Scalar(0, 0, 0), 1);
        }

        return src;
    }

    void ObjectDetector::detect(Mat image, std::vector<DetectionResult> *results) {
        // Load image
        // Input type (quantized or not)
        if (input_type == kTfLiteUInt8) {
            memcpy(input_tensor->data.uint8, image.data,
			   sizeof(uint8_t) * TFLITE_MODEL_SIZE * TFLITE_MODEL_SIZE * TFLITE_MODEL_CHANNELS);
        } 
        else if (input_type == kTfLiteFloat32){
            memcpy(input_tensor->data.uint8, image.data.f,
			   sizeof(float) * TFLITE_MODEL_SIZE * TFLITE_MODEL_SIZE * TFLITE_MODEL_CHANNELS);
        } 
        else {
            std::cerr << "ERROR: Wrong interpreter input type <" << input_type << "> (<kTfLiteUInt8> or <kTfLiteFloat32> expected)";
            exit(EXIT_FAILURE);
        }

        // Invoke interpreter
        if (interpreter->Invoke() != kTfLiteOk) {
		    std::cerr << "ERROR: Failed to invoke tflite";
		    exit(EXIT_FAILURE);
        }

        // Retrieve results from tensors
        const float *detection_locations = output_locations_tensor->data.f;
        const float *detection_classes = output_classes_tensor->data.f;
        const float *detection_scores = output_scores_tensor->data.f;
        const int num_detections = (int) *num_detections_tensor->data.f;
        results->clear();

        for (int i = 0; i < num_detections; i++) {
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

    void usage() {
        std::cout 
            << "Usage: object_detection\n"
            << "\t--image, -i: image_name.jpg\n"
            << "\t--tflite_model, -m: model_name.tflite\n"
            << "\t--labels, -l: labels of the model (.txt)\n"
            << "\t--output_file, -o: output_file.jpg\n"
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
                // {"threads", required_argument, nullptr, 't'},
                {"help", required_argument, nullptr, 'h'},
                {nullptr, 0, nullptr, 0}};
            
            int option_index = 0;
            c = getopt_long(argc, argv, "i:l:m:o:h", long_options, &option_index);

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
        od.run(s.image, s.output_file);
    }
} // namespace tflite 
} // namespace object_detection

int main(int argc, char **argv) {
    return tflite::object_detection::Main(argc, argv);
}