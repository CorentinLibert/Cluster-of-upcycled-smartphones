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
    
EXPOSE 18080