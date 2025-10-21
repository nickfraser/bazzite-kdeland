#!/bin/bash

set -ouex pipefail

BASEDIR="$(dirname "$(realpath "$0")")"

### Install packages
${BASEDIR}/scripts/docker.sh # BUILD_DOCKER=1 to install docker
${BASEDIR}/scripts/kvm.sh # BUILD_KVM=1 to install KVM
${BASEDIR}/scripts/initramfs.sh # BUILD_KVM=1 - I think required after installing KVM
${BASEDIR}/scripts/clean.sh
