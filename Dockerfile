# Start image from Alpine Linux
FROM arm32v7/alpine:latest

# Could add --no-cache to apk add, however you will have to download everything each time
RUN apk update && \
    apk add \ 
        bash \
        cmake \
        curl \
        g++ \
        gcc \
        libstdc++ \
        git \
        musl \
        musl-dev \
        make \
        zip

# ==================================
# Download TensorFlow and toolchain
# ==================================
# ENV TENSORFLOW_VERSION 2.15
ENV SRC_PATH /tensorflow/armv7l_build/src
ENV TOOLCHAIN_PATH ${SRC_PATH}/toolchains

VOLUME /src /src

WORKDIR ${SRC_PATH}

# # Clone source code of release 2.15 into tensorflow_src
# RUN git clone --branch r2.15 https://github.com/tensorflow/tensorflow.git tensorflow_src

# # Download the armv7l musl toolchain
# RUN curl -LO https://musl.cc/armv7l-linux-musleabihf-cross.tgz
# RUN mkdir -p toolchains
# RUN tar xvf armv7l-linux-musleabihf-cross.tgz -C toolchains
# RUN rm armv7l-linux-musleabihf-cross.tgz


# ==================================
# Build TensorFlow Lite
# ==================================
# RUN mkdir tflite_build
# WORKDIR ${SRC_PATH}/tflite_build

ENV ARMCC_FLAGS="-march=armv7-a -mfpu=neon-vfpv4 -funsafe-math-optimizations -mfp16-format=ieee"
ENV ARMCC_PREFIX=${TOOLCHAIN_PATH}/armv7l-linux-musleabihf-cross/bin/armv7l-linux-musleabihf-
# RUN cmake -DCMAKE_C_COMPILER=${ARMCC_PREFIX}gcc \
#   -DCMAKE_CXX_COMPILER=${ARMCC_PREFIX}g++ \
#   -DCMAKE_C_FLAGS="${ARMCC_FLAGS}" \
#   -DCMAKE_CXX_FLAGS="${ARMCC_FLAGS}" \
#   -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
#   -DCMAKE_SYSTEM_NAME=Linux \
#   -DCMAKE_SYSTEM_PROCESSOR=armv7 \
#   ../tensorflow_src/tensorflow/lite/examples/label_image

cmake -DCMAKE_C_COMPILER=${ARMCC_PREFIX}gcc \
  -DCMAKE_C_FLAGS="${ARMCC_FLAGS}" \
  -DCMAKE_CXX_FLAGS="${ARMCC_FLAGS}" \
  -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
  ../tensorflow_src/tensorflow/lite/examples/label_image