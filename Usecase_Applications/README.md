# Docker development environment setup

The following instructions will allow you to set up a docker environment to cross-compile your **TensorFlow Lite**, **OpenCV** and **Crow** projects for devices with `armv7l` processor under distribution using `musl libc`.

Docker offers images under different distributions for different processor's architecture, in our case [`arm32v7/alpine`](https://hub.docker.com/r/arm32v7/alpine/). It can be associated with [`qemu`](https://www.qemu.org/), which offers a virtual layer allowing the emulation of a processor, as a means for cross-compilation, instead of using a toolchain.

## Requirements
