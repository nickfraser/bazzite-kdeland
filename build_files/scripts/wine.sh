#!/bin/bash

set -ouex pipefail

if [[ BUILD_WINE -eq "1" ]]; then
    dnf5 install -y \
        wine
fi
