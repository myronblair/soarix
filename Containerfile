# Soarix - Copyright (c) TomTom Enterprises. Open source.
FROM scratch AS ctx
COPY build_files /
COPY VERSION /VERSION
COPY system_files /system_files

# Base: Fedora's official bootc (atomic, image-based) image
FROM quay.io/fedora/fedora-bootc:44
ARG SOARIX_VERSION=0.3.0
LABEL org.opencontainers.image.source="https://github.com/myronblair/soarix" \
      org.opencontainers.image.version="${SOARIX_VERSION}"

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

RUN bootc container lint
