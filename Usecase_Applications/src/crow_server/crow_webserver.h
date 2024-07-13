#ifndef CROW_WEBSERVER_H
#define CROW_WEBSERVER_H

#include "crow.h"

namespace crow_webserver {

struct Settings {
    std::string input_file = "input.bmp";
    std::string output_file = "output.bmp";
    int threads = 1;
    int port = 18080;
};

} // namespace crow_webserver

#endif