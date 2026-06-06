#!/bin/bash

set -ouex pipefail

SCRIPTDIR="$(dirname "$(realpath "$0")")"
source "${SCRIPTDIR}/dnf.sh"

if [[ BUILD_KVM -eq "1" ]]; then
    # Install KVM
    dnf5_guarded install -y \
        @virtualization \
        qemu-kvm \
        libvirt \
        virt-install \
        virt-manager

    # Enable docker
    systemctl enable libvirtd
fi
