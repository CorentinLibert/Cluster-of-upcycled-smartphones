# OpenCV test example

A simple OpenCV's example written in C++ by ChatGPT to ensure that OpenCV is installed properly by compiling the project.

When executed, the built executable takes an image called `input.jpg` from the current directory and draws a red square in the middle of it before saving it in the current directory under the name "squared_image.jpg".

## Build the executable

Create a build directory:

```
mkdir build && cd build
```

Configure the project with CMake:

```
cmake ..
```

Compile the project:

```
make
```

## Run the executable

To run the executable, simply execute the following command with the image `input.jpg` in the same directory:

```
./draw_square
```