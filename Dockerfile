# Build Stage
FROM --platform=linux/amd64 ubuntu:20.04 as builder

## Install build dependencies.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y cmake 

## Add source code to the build stage.
ADD . /blurhash
WORKDIR /blurhash

## TODO: ADD YOUR BUILD INSTRUCTIONS HERE.
RUN cd C && make blurhash_encoder

# Package Stage
FROM --platform=linux/amd64 ubuntu:20.04

## TODO: Change <Path in Builder Stage>
COPY --from=builder /blurhash/C/blurhash_encoder /

