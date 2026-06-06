#!/bin/bash

set -ouex pipefail

SCRIPTDIR="$(dirname "$(realpath "$0")")"
source "${SCRIPTDIR}/dnf.sh"

if [[ BUILD_WINE -eq "1" ]]; then
    dnf5_guarded install -y \
        wine
fi
