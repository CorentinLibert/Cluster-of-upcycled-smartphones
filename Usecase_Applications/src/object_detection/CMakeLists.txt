cmake_minimum_required(VERSION 3.16)
project(ObjectDetection C CXX)

# set(OpenCV_STATIC ON)

find_package(OpenCV REQUIRED)

set(TENSORFLOW_SOURCE_DIR "" CACHE PATH
  "Directory that contains the TensorFlow project"
)
if(NOT TENSORFLOW_SOURCE_DIR)
  get_filename_component(TENSORFLOW_SOURCE_DIR
    "${CMAKE_CURRENT_LIST_DIR}/../../../../"
    ABSOLUTE
  )
endif()

add_subdirectory(
  "${TENSORFLOW_SOURCE_DIR}/tensorflow/lite"
  "${CMAKE_CURRENT_BINARY_DIR}/tensorflow-lite"
  EXCLUDE_FROM_ALL
)

include_directories(${OpenCV_INCLUDE_DIRS})

set(CMAKE_CXX_STANDARD 17)
add_executable(ObjectDetection
  object_detection.cc
)
target_link_libraries(ObjectDetection
  tensorflow-lite
)
target_link_libraries(ObjectDetection ${OpenCV_LIBS})
