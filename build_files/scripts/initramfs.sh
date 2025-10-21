#!/bin/bash

set -ouex pipefail

if [[ BUILD_KVM -eq "1" ]]; then
    # Get kernel version and build initramfs
    KERNEL_VERSION="$(rpm -q --queryformat='%{evr}.%{arch}' kernel)"
    /usr/bin/dracut \
      --no-hostonly \
      --kver "$KERNEL_VERSION" \
      --reproducible \
      --zstd \
      -v \
      --add ostree \
      -f "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"

    chmod 0600 "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"
fi
