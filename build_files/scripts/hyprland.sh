#!/bin/bash

set -ouex pipefail

if [[ BUILD_HYPRLAND -eq "1" ]]; then
    dnf5 -y copr enable solopasha/hyprland
    dnf5 -y install \
        blueman \
        brightnessctl \
        grimshot \
        hyprland \
        hyprpaper \
        hyprpicker \
        hypridle \
        hyprlock \
        hyprsunset \
        hyprpolkitagent \
        hyprsysteminfo \
        hyprpanel \
        hyprland-guiutils \
        hyprland-qt-support	\
        qt6ct-kde			\
        terminator \
        tesseract \
        network-manager-applet \
        pavucontrol \
        waybar \
        wofi \
        xdg-desktop-portal-hyprland
    dnf5 -y copr disable solopasha/hyprland
fi
