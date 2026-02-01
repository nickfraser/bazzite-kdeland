#!/bin/bash

set -ouex pipefail

if [[ BUILD_HYPRLAND -eq "1" ]]; then
    dnf5 -y copr enable ashbuk/Hyprland-Fedora
    dnf5 -y install \
        blueman \
        brightnessctl \
        grimshot \
        hyprland \
        hyprland-qtutils \
        hyprpicker \
        hypridle \
        hyprlock \
        network-manager-applet \
        pavucontrol \
        terminator \
        tesseract \
        waybar \
        wofi \
        xdg-desktop-portal-hyprland
    dnf5 -y copr disable ashbuk/Hyprland-Fedora
fi
