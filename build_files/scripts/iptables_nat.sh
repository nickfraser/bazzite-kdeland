#!/bin/bash

set -ouex pipefail

if [[ BUILD_DOCKER -eq "1" ]] || [[ BUILD_KVM -eq "1" ]]; then
    # Load iptable_nat module for docker-in-docker, NAT in KVM.
    # Source: https://github.com/ublue-os/bazzite-dx/blob/main/build_files/20-install-apps.sh
    # See:
    #   - https://github.com/ublue-os/bluefin/issues/2365
    #   - https://github.com/devcontainers/features/issues/1235
    mkdir -p /etc/modules-load.d && cat >>/etc/modules-load.d/ip_tables.conf <<EOF
iptable_nat
EOF
fi
