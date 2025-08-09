#!/bin/bash

set -ouex pipefail

if [[ BUILD_HYPRLAND -eq "1" ]]; then
    dnf5 install -y \
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
