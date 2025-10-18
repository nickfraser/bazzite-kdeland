#!/bin/bash

set -ouex pipefail

# Sourced from: https://github.com/ublue-os/bazzite-dx/blob/main/build_files/999-cleanup.sh

# Clean package manager cache
dnf5 clean all

# Clean temporary files
rm -rf /tmp/*

# Cleanup the entirety of `/var`.
# None of these get in the end-user system and bootc lints get super mad if anything is in there
rm -rf /var
mkdir -p /var

# Commit and lint container
bootc container lint || true

echo "Cleanup completed"
