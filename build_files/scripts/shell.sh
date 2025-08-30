#!/bin/bash

set -ouex pipefail

if [[ BUILD_SHELL -eq "1" ]]; then
    dnf5 install -y \
        git \
        git-lfs \
        htop \
        p7zip \
        podman-compose \
        qpdf \
        screen \
        vim
fi
