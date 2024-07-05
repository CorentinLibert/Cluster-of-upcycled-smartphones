#ifndef TENSORFLOW_LITE_OBJECT_DETECTION_OBJECT_DETECTION_H_
#define TENSORFLOW_LITE_OBJECT_DETECTION_OBJECT_DETECTION_H_

// Includes
#include "include/tensorflow/lite/model.h"
// #include <opencv2/core.hpp>

namespace tflite {
namespace object_detection {
    // Based on: https://github.com/tensorflow/tensorflow/blob/master/tensorflow/lite/examples/label_image/label_image.h
    struct Settings {
        std::string image;
        std::string labels;
        std::string tflite_model;
        std::string output_file;
        int threads = 1;
    };
    
    // Credit:  https://github.com/ValYouW/crossplatform-tflite-object-detecion/tree/master/native-detector
    struct DetectionResult {
        int label = -1;
        float score = 0;
        float ymin = 0.0;
        float xmin = 0.0;
        float ymax = 0.0;
        float xmax = 0.0;
    };

    // Metadata from tflite model "ssd_mobilenet-v1-tflite" from https://www.kaggle.com/models/tensorflow/ssd-mobilenet-v1/tfLite/metadata
    class ObjectDetector {
        public:
            // Methods
            ObjectDetector(Settings s);
            void run(std::string input_path, std::string output_path);
        private:
            // cf. model metadata
            const int TFLITE_MODEL_SIZE = 300;
            const int TFLITE_MODEL_CHANNELS = 3;
            const float IMAGE_MEAN = 127.5;
            const float IMAGE_STD = 127.5;
            std::vector<string>* labels = nullptr;
            std::unique_ptr<tflite::FlatBufferModel> model;
            std::unique_ptr<tflite::Interpreter> interpreter;
            TfLiteType input_type;
            TfLiteTensor *input_tensor = nullptr;
            TfLiteTensor *output_locations_tensor = nullptr;
            TfLiteTensor *output_classes_tensor = nullptr;
            TfLiteTensor *output_scores_tensor = nullptr;
            TfLiteTensor *num_detections_tensor = nullptr;

            // Methods
            void read_labels(std::string labels_path);
            Map image_preprocessing(std::string input_path);
            Map image_postprocessing(std::string input_path, std::string output_path, std::vector<DetectionResult> *detection_results);
            void detect(Map image, std::vector<DetectionResult> *results);
    };

    
    
} // namespace tflite 
} // namespace object_detection


#endif  // TENSORFLOW_LITE_OBJECT_DETECTION_OBJECT_DETECTION_H_