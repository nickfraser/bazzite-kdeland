#!/bin/bash

set -ouex pipefail

if [[ BUILD_HYPRLAND -eq "1" ]]; then
    dnf5 -y copr enable ashbuk/Hyprland-Fedora
    dnf5 -y install \
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
    dnf5 -y copr disable ashbuk/Hyprland-Fedora
fi
