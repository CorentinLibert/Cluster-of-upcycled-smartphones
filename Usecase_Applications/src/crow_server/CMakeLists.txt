# Specify the minimum version for CMake
cmake_minimum_required(VERSION 3.10)
project(CrowWebserver)

set(CMAKE_CXX_STANDARD 11)

# For json parsing
find_package(nlohmann_json 3.11.3 REQUIRED)

add_executable(crow_webserver crow_webserver.cc)

# Link pthread and nlohmann_json library
target_link_libraries(crow_webserver 
                        pthread 
                        nlohmann_json::nlohmann_json)