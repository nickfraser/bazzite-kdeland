#!/bin/bash

set -ouex pipefail

if [[ BUILD_DOCKER -eq "1" ]]; then
    # Instructions from: https://docs.docker.com/engine/install/fedora/
    # Remove packages that clash with official docker package
    dnf5 remove -y \
        docker \
        docker-client \
        docker-client-latest \
        docker-common \
        docker-latest \
        docker-latest-logrotate \
        docker-logrotate \
        docker-selinux \
        docker-engine-selinux \
        docker-engine

    # Install docker repo
    dnf5 -y install dnf-plugins-core
    dnf5 config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
    dnf5 config-manager setopt docker-ce-stable.enabled=0

    # Install docker
    dnf5 install -y \
        --enable-repo="docker-ce-stable" \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    # Enable docker
    systemctl enable docker.socket

    # Load iptable_nat module for docker-in-docker.
    # See:
    #   - https://github.com/ublue-os/bluefin/issues/2365
    #   - https://github.com/devcontainers/features/issues/1235
    mkdir -p /etc/modules-load.d && cat >>/etc/modules-load.d/ip_tables.conf <<EOF
iptable_nat
EOF
fi
