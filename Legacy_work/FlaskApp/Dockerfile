FROM python:3.12-alpine
WORKDIR /app
COPY . .
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
RUN pip install Flask
RUN pip install waitress
EXPOSE 5000
CMD ["python", "app.py"]
