#!/bin/bash

set -ouex pipefail

if [[ BUILD_HYPRLAND -eq "1" ]]; then
    dnf5 -y copr enable solopasha/hyprland
    dnf5 -y install \
        blueman \
        brightnessctl \
        grimshot \
        hyprland \
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
    dnf5 -y copr disable solopasha/hyprland
fi
