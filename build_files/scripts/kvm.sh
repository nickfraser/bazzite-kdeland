#!/bin/bash

set -ouex pipefail

if [[ BUILD_KVM -eq "1" ]]; then
    # Install KVM
    dnf5 install -y \
        @virtualization \
        qemu-kvm \
        libvirt \
        virt-install \
        virt-manager

    # Enable docker
    systemctl enable libvirtd
fi
