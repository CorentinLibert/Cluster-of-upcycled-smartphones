#include <opencv2/opencv.hpp>

// Code made by ChatGPT, only used as an example to test if OpenCV is installed properly
int main() {
    // Read the image file
    cv::Mat image = cv::imread("input.jpg");

    // Check for failure
    if (image.empty()) {
        std::cout << "Could not open or find the image" << std::endl;
        return -1;
    }

    // Get image dimensions
    int width = image.cols;
    int height = image.rows;

    // Define the size of the square
    int squareSize = std::min(width, height) / 4;

    // Calculate the top-left and bottom-right points of the square
    cv::Point topLeft((width - squareSize) / 2, (height - squareSize) / 2);
    cv::Point bottomRight((width + squareSize) / 2, (height + squareSize) / 2);

    // Draw a red square
    cv::rectangle(image, topLeft, bottomRight, cv::Scalar(0, 0, 255), -1); // -1 indicates filled rectangle

    // Save the image
    cv::imwrite("squared_image.jpg", image);

    return 0;
}
