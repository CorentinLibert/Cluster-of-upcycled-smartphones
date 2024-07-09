#include <fstream>
#include <iostream>
#include <string>
#include <vector>
#include <chrono>

#include "crow.h"
//#include "crow_all.h"

using namespace std;

crow::response handle_image(const crow::request& req, std::string& file) {
    auto start = std::chrono::high_resolution_clock::now();
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
    std::ofstream out(file, std::ios::out | std::ios::binary);
    if (!out.is_open()) {
        return crow::response(crow::status::INTERNAL_SERVER_ERROR, "Could not save the image: output file not opening.\n");
    }
    out.write(image_data.c_str(), image_data.length());
    out.close();

    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double, std::nano> duration = end - start;
    std::cout << std::fixed << "crow,handling," << duration.count() << std::endl;

    return crow::response(crow::status::OK);
}

crow::response process_image(std::string in_file, std::string out_file) {
    auto start = std::chrono::high_resolution_clock::now();
    
    std::ifstream in(in_file);
    std::ofstream out(out_file);
    if (!in.is_open()) {
        return crow::response(crow::status::INTERNAL_SERVER_ERROR, "Could not process the image: input file not opening.\n");
    }
    if (!out.is_open()) {
        return crow::response(crow::status::INTERNAL_SERVER_ERROR, "Could not process the image: output file not opening.\n");
    }

    std::string line;
    while (getline(in, line)) {
        out << line << std::endl;
    }

    in.close();
    out.close();

    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double, std::nano> duration = end - start;
    std::cout << std::fixed << "crow,processing," << duration.count() << std::endl;

    return crow::response(crow::status::OK);
}

crow::response send_image(std::string file) {
    auto start = std::chrono::high_resolution_clock::now();

    crow::response res;
    res.set_static_file_info(file);
    res.set_header("Content-Type", "application/octet-stream");

    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double, std::nano> duration = end - start;
    std::cout << std::fixed << "crow,sending," << duration.count() << std::endl;

    return res;
}

crow::response object_detection(const crow::request& req) {
    std::string data_file = "data_bitmap.bmp";
    std::string res_file = "res_bitmap.bmp";
    crow::response res = handle_image(req, data_file);
    if (res.code != 200) { return res; }
    res = process_image(data_file, res_file);
    if (res.code != 200) { return res; }
    res = send_image(res_file);
    return res;
}

int main()
{
    crow::SimpleApp app;

    CROW_ROUTE(app, "/")([](){
        return "Hello world";
    });

    CROW_ROUTE(app, "/object_detection").methods(crow::HTTPMethod::POST)([](const crow::request& req){
        return object_detection(req);
    });

    // Set the port, set the app to run on multiple threads, and run the app
    app.port(18080).multithreaded().run();
}
