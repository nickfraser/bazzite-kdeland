#!/bin/bash

set -ouex pipefail

BASEDIR="$(dirname "$(realpath "$0")")"

if [[ BUILD_LAPTOP -eq "1" ]]; then
    if [[ BUILD_LAPTOP_CLAMSHELL -eq "1" ]]; then
        mkdir -p /etc/systemd/logind.conf.d
        # TODO: Merge with any existing files
        cp ${BASEDIR}/etc/systemd/logind.conf /etc/systemd/logind.conf
        cp ${BASEDIR}/etc/systemd/logind.conf.d/60-logind-lid-switch.conf /etc/systemd/logind.conf.d/60-logind-lid-switch.conf # Both of these files seem to be required for some reason
    fi
    if [[ BUILD_LAPTOP_OPENRAZER -eq "1" ]]; then
        printf '%s\n' \
            'BUILD_LAPTOP_OPENRAZER=1 is temporarily unsupported in this image.' \
            'The old ujust install-openrazer path pulls openrazer-kernel-modules-dkms,' \
            'which fails on rpm-ostree/bootc systems because DKMS writes to /var/lib/dkms' \
            'during the transaction. No image-compatible replacement is available yet.' >&2
        exit 1
    fi
fi
