#include <fstream>
#include <iostream>
#include <string>
#include <vector>

#include "crow.h"
//#include "crow_all.h"

crow::response handle_image(const crow::request& req, std::string& file) {
    // Check if request's content-type is multipart
    const std::string& req_content_type = req.get_header_value("Content-Type");
    const std::string& multipart_content_type = "multipart/form-data";
    // This version of c++ does not support "contains()"
    if (req_content_type.find(multipart_content_type) == std::string::npos) {
        return crow::response(crow::status::BAD_REQUEST, "Invalid content type: multipart/form-data expected.\n");
    }

    // Check if the request contains an image
    crow::multipart::message msg(req);
    crow::multipart::part image_part = msg.get_part_by_name("image");
    std::string img_content_type = image_part.get_header_object("Content-Type").value;
    const std::string& octet_stream_content_type = "application/octet-stream";
    // This version of c++ does not support "contains()"
    if (img_content_type.find(octet_stream_content_type) == std::string::npos) {
        return crow::response(crow::status::BAD_REQUEST, "Missing image data.\n");
    }

    // Save the bitmap image in local
    std::string image_data = image_part.body;
    std::ofstream out(file);
    if (!out.is_open()) {
        return crow::response(crow::status::INTERNAL_SERVER_ERROR, "Could not save the image: output file not opening.\n");
    }
    out << image_data;
    out.close();

    return crow::response(crow::status::OK);
}

crow::response process_image(const crow::request& req, std::string in_file, std::string out_file) {
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
    return crow::response(crow::status::OK);
}


// Based on https://stackoverflow.com/questions/77580304/crow-multipart-response
crow::response send_image(const crow::request& req, std::string file) {
    std::ifstream in(file);
    if (!in.is_open()) {
        return crow::response(crow::status::INTERNAL_SERVER_ERROR, "Could not send the image: input file not opening.\n");
    }

    std::vector<std::string> buffer;
    std::string line;
    while (getline(in, line)) {
        line += '\n';
        buffer.push_back(line);
    }
    std::string res_image(buffer.begin(), buffer.end());

    crow::response res;
    res.set_header("Content-Type", "application/octet-stream");
    res.write(res_image);
    return res;
}

crow::response object_detection(const crow::request& req) {
    std::string data_file = "data_bitmap.bmp";
    std::string res_file = "res_bitmap.bmp";
    crow::response res = handle_image(req, data_file);
    if (res.code != 200) { return res; }
    res = process_image(req, data_file, res_file);
    if (res.code != 200) { return res; }
    res = send_image(req, res_file);
    return res;
}

int main()
{
    crow::SimpleApp app; //define your crow application

    //define your endpoint at the root directory
    CROW_ROUTE(app, "/")([](){
        return "Hello world";
    });

    CROW_ROUTE(app, "/object_detection").methods(crow::HTTPMethod::POST)([](const crow::request& req){
        return object_detection(req);
    });

    //set the port, set the app to run on multiple threads, and run the app
    app.port(18080).multithreaded().run();
}
