#!/bin/bash

set -ouex pipefail

SCRIPTDIR="$(dirname "$(realpath "$0")")"
source "${SCRIPTDIR}/dnf.sh"

if [[ BUILD_HYPRLAND -eq "1" ]]; then
    dnf5_guarded install -y \
        blueman \
        brightnessctl \
        grimshot \
        hyprland \
        network-manager-applet \
        pavucontrol \
        swaylock \
        terminator \
        tesseract \
        waybar \
        wofi \
        xdg-desktop-portal-hyprland
fi
