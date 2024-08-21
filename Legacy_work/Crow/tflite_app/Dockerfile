FROM arm32v7/alpine:latest

# Could add --no-cache to apk add, however you will have to download everything each time
RUN apk update && \
    apk add \
        nano \
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
        zip \
        asio-dev

RUN git clone https://github.com/CrowCpp/Crow.git
RUN cd Crow && \
    mkdir build && \
    cd build && \
    cmake .. -DCROW_BUILD_EXAMPLES=OFF -DCROW_BUILD_TESTS=OFF && \
    make install


RUN mkdir OpenCV && cd OpenCV && \
    wget -O opencv.zip https://github.com/opencv/opencv/archive/4.x.zip && \
    unzip opencv.zip && rm opencv.zip && \
    mkdir build && cd build && \
    cmake -DBUILD_SHARED_LIBS=OFF ../opencv-4.x && \
    make -j4

RUN cd && \
    git clone --branch "v2.16.1" https://github.com/tensorflow/tensorflow.git tensorflow_src && \
    


EXPOSE 18080