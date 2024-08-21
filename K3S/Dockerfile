FROM alpine:latest
COPY ./label_image_with_crow_app /app
WORKDIR /app
RUN apk update && \
    apk add \
        libstdc++ \
        bash \
        nano

EXPOSE 18080
ENTRYPOINT ["./label_image_with_crow"]
CMD ["-c", "config.json"]
