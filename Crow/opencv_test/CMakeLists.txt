cmake_minimum_required(VERSION 3.10)
project(DrawSquare)

# Find OpenCV package
find_package(OpenCV REQUIRED)

# Include OpenCV headers
include_directories(${OpenCV_INCLUDE_DIRS})

# Add executable
add_executable(draw_square draw_square.cc)

# Link OpenCV libraries
target_link_libraries(draw_square ${OpenCV_LIBS})
