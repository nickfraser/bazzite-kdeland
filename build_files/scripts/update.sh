#!/bin/bash

set -ouex pipefail

SCRIPTDIR="$(dirname "$(realpath "$0")")"
source "${SCRIPTDIR}/dnf.sh"

if [[ BUILD_UPDATE -eq "1" ]]; then
    dnf5_guarded upgrade -y --refresh
fi
