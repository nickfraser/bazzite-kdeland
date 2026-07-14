#!/bin/bash

set -ouex pipefail

SCRIPTDIR="$(dirname "$(realpath "$0")")"
BASEDIR="$(realpath "${SCRIPTDIR}/..")"
DROPINDIR="/usr/lib/systemd/user/plasma-login-kwin_wayland.service.d"
SOURCEDIR="${BASEDIR}/etc/systemd/user/plasma-login-kwin_wayland.service.d"

mkdir -p "${DROPINDIR}"
cp "${SOURCEDIR}/10-force-sw-cursor.conf" "${DROPINDIR}/10-force-sw-cursor.conf"

# Leave the hybrid-GPU ordering override out of the default image for now so
# we can validate the software-cursor workaround independently first.
rm -f "${DROPINDIR}/20-prefer-amd-primary.conf"
