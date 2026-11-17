# Soarix - Copyright (c) TomTom Enterprises. Open source.
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

# Base: Fedora's official bootc (atomic, image-based) image
FROM quay.io/fedora/fedora-bootc:44

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

RUN bootc container lint
