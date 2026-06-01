#!/bin/bash

set -ouex pipefail

if [[ BUILD_UPDATE -eq "1" ]]; then
    dnf5 upgrade -y
fi
