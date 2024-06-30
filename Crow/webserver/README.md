# Simple Webserver

This folder contains 2 implementations of a simple web server application, one in Python using Flask, and the other in C++ using Crow.

The web server behaves as follows:
- **[POST]** /object_detection
    - The server handles the request and downloads the image from the body locally.
    - The server processes the image. Here it simply creates a copy of it by opening the image file, reading it and writing back to another file. This part simply simulates processing, it is not efficiently done. 
    - The sender sends back the image copy to the client.
- **[GET]** /
    - Simply return an "Hello world".

The [measurements](./measurements/) folder shows the performances of both implementations. The *crow_<<* implementation is not available anymore but simply consists of replacing the `out.write(image_data, image_data.length())` line in the [crow implementation](./crow_webserver.cc) (corresponding to the *crow_write* implementation) by `out << image_data`. This was less performant as shown on the [graph](./measurements/comparison_flask_vs_crow_webserver.jpg).

The [results](./measurements/comparison_flask_vs_crow_webserver.jpg) show that the Flask and Crow implementations perform similarly well, except for the processing. This can be explained by the fact the processing on the Crow implementation is poorly coded. The Crow implementation even outperforms the Flask implementation for the *handling* process.

