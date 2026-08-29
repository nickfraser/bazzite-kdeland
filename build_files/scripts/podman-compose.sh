#!/bin/bash

set -ouex pipefail

SCRIPTDIR="$(dirname "$(realpath "$0")")"
source "${SCRIPTDIR}/dnf.sh"

if [[ BUILD_PODMAN_COMPOSE -eq "1" ]]; then
    dnf5_guarded install -y podman-compose
fi
