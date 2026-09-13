# BUILD_FROM_IMAGE definition MUST be the first (uncommented) line: https://stackoverflow.com/a/78364729
ARG BUILD_FROM_IMAGE=ghcr.io/ublue-os/bazzite-nvidia-open:stable-44
ARG OPENRAZER_AKMODS_IMAGE=base_image
# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Image
FROM ${BUILD_FROM_IMAGE} AS base_image

# Exact-kernel UBlue kmods resolved from the selected Bazzite base image.
FROM ${OPENRAZER_AKMODS_IMAGE} AS openrazer_rpms

FROM base_image

# Build args
ARG BUILD_UPDATE
ARG BUILD_HYPRLAND
ARG BUILD_LAPTOP
ARG BUILD_LAPTOP_CLAMSHELL
ARG BUILD_LAPTOP_OPENRAZER
ARG BUILD_CITRIX
ARG BUILD_CITRIX_DEPS_ONLY
ARG BUILD_DOCKER
ARG BUILD_WINE
ARG BUILD_KVM

# Layer on my own customizations
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=bind,from=openrazer_rpms,source=/,target=/var/tmp/openrazer-rpms \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh && \
    ostree container commit
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    mkdir -p /var/roothome && \
    /ctx/build-system.sh && \
    ostree container commit
    
### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
