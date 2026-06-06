#!/bin/bash

set -ouex pipefail

SCRIPTDIR="$(dirname "$(realpath "$0")")"
source "${SCRIPTDIR}/dnf.sh"

if [[ BUILD_SHELL -eq "1" ]]; then
    dnf5_guarded install -y \
        git \
        git-lfs \
        htop \
        p7zip \
        podman-compose \
        qpdf \
        screen \
        vim
fi
