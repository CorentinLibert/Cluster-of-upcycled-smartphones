# Docker development environment setup

The following instructions will allow you to set up a docker environment to cross-compile your **TensorFlow Lite**, **OpenCV** and **Crow** projects for devices with `armv7l` processor under distribution using `musl libc`.

Docker offers images under different distributions for different processor's architecture, in our case [`arm32v7/alpine`](https://hub.docker.com/r/arm32v7/alpine/). It can be associated with [`qemu`](https://www.qemu.org/), which offers a virtual layer allowing the emulation of a processor, as a means for cross-compilation, instead of using a toolchain.

## Requirements
There are several requirements to set up the docker development environment setup. We've listed them below and indicated to you how to meet them on Linux Ubuntu

- Install Docker: Obviously, you need to install Docker. Follow the [installation instructions for Docker](https://docs.docker.com/engine/install/ubuntu/)
- Install Qemu: On Ubuntu 

## Steps

First, you should build the docker image from the docker file:

```
docker build . -t armv7l-musl-dev-image
```

Then you can create a container from the built docker image. Specify the platform, here `linux/arm`, and create a shared volume between the folder with your code on your machine and a folder in the container, here `${PWD}:/root/Usecase_Applications` since we are in the development folder. You may want to forward a port in case you want to test a networking application, here `-p 18080:18080`. We've made the container *interactive*, `-i`, and have allocated a *pseudo-TTY*, `-t`. All together, we got the following command:

```
docker run --platform linux/arm -it -p 18080:18080 -v ${PWD}:/root/Usecase_Applications armv7l-musl-dev-crow-opencv-tflite-image
```