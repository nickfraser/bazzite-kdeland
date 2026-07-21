#!/bin/bash

set -ouex pipefail

SCRIPTDIR="$(dirname "$(realpath "$0")")"
BASEDIR="$(realpath "${SCRIPTDIR}/..")"
DROPINDIR="/usr/lib/systemd/user/plasma-login-kwin_wayland.service.d"
SOURCEDIR="${BASEDIR}/etc/systemd/user/plasma-login-kwin_wayland.service.d"

mkdir -p "${DROPINDIR}"
cp "${SOURCEDIR}/10-force-sw-cursor.conf" "${DROPINDIR}/10-force-sw-cursor.conf"
