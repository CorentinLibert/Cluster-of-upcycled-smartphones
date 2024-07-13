#include <fstream>
#include <iostream>
#include <string>
#include <vector>
#include <chrono>

#include "crow.h"
//#include "crow_all.h"
#include "crow_webserver.h"
#include <getopt.h>     // NOLINT(build/include_order)
#include <nlohmann/json.hpp>

using json = nlohmann::json;


namespace crow_webserver {

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

    // Add your processing here. 
    // We just copy input file into output file for the moment.
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

crow::response object_detection(Settings *settings, const crow::request& req) {
    crow::response res = handle_image(req, settings->input_file);
    if (res.code != 200) { return res; }
    res = process_image(settings->input_file, settings->output_file);
    if (res.code != 200) { return res; }
    res = send_image(settings->output_file);
    return res;
}

crow::response label_image(Settings *settings, const crow::request& req) {
    crow::response res = handle_image(req, settings->input_file);
    if (res.code != 200) { return res; }
    res = process_image(settings->input_file, settings->output_file);
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


void parse_configfile_to_settings(const std::string& filename, Settings *settings) {
    std::ifstream file(filename);
    json config;
    file >> config;

    // Setup server settings
    if (config.contains("input_file")) settings->input_file = config["input_file"];
    if (config.contains("output_file")) settings->output_file = config["output_file"];
    if (config.contains("port")) settings->port = config["port"];
    if (config.contains("threads")) settings->threads = config["threads"];
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
    Settings s;
    std::string configfile = parsing_arguments(argc, argv);
    parse_configfile_to_settings(configfile, &s);

    // Crow app
    crow::SimpleApp app;

    CROW_ROUTE(app, "/")([](){
        return "Hello world";
    });

    CROW_ROUTE(app, "/object_detection").methods(crow::HTTPMethod::POST)([&s](const crow::request& req){
        return object_detection(&s, req);
    });

    CROW_ROUTE(app, "/label_image").methods(crow::HTTPMethod::POST)([&s](const crow::request& req){
        return label_image(&s, req);
    });

    // Set the port, set the app to run on multiple threads, and run the app
    app.port(s.port).concurrency(s.threads).run();
    return 0;
}

} //namespace crow_webserver 

int main(int argc, char** argv) {
  return crow_webserver::Main(argc, argv);
}

