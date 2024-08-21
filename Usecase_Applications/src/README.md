# Usecase Applications: Source codes

This folder contains several source codes of various use case applications implemented in `C++`. We will give you a brief description of each one.

## Crow Server

This is a simple webserver developed using the [`Crow C++ framework`](https://crowcpp.org/master/). The following functions have been implemented:

- Handling `POST` requests containing a bitmap image and saving it locally.
- Processing a local image and saving the result locally as a new image (partially implemented and not used).
- Sending to the client a local image.

The web server has 2 applications implemented:

- `/object_detection`: Run the object detection application on the image in the post request and return an image with boxes around recognized objects annotated with their label and their confidence score.
- `/label_image`: Run the label image application on the image in the post request and return a text with the 5 most likely labels and their confidence score.

## Label image

The example application from TensorFlow Lite and refactored to be more modulable. The *Setup of the interpreter* has been separated from the part *running the inference*.
Code has been added to be able to perform time execution analysis on each import part of the application.

## Label image with Crow

The same application as [Label image](#label-image) to which part of the [Crow Server](#crow-server) has been added to enable HTTP request handling.
Instead of taking a lot of argument as for [Label image](#label-image), this implementation works by passing a `json` configuration file with all the parameters (see the template in the folder).

## Object Detection

An application written in C++ using TensorFlow and OpenCV that allows to perform object detection on images. Not used because the application is not performant enough and takes too much time.

## Object Detection using Yolo

The same application as [Object Detection](#object-detection) but adapted to use the [Yolo models for object detection](https://docs.ultralytics.com/models/). Not used because the application is not performant enough and takes too much time.
