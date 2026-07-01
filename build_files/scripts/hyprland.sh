#!/bin/bash

set -ouex pipefail

SCRIPTDIR="$(dirname "$(realpath "$0")")"
source "${SCRIPTDIR}/dnf.sh"

if [[ BUILD_HYPRLAND -eq "1" ]]; then
    # Hyprland was retired from Fedora 44 official repos, so install it from
    # the ashbuk/Hyprland-Fedora COPR instead. Use plain dnf5 for the COPR
    # packages to allow vendor changes; keep everything else under dnf5_guarded
    # so Bazzite's kernel/graphics stack is left untouched.
    dnf5 -y copr enable ashbuk/Hyprland-Fedora

    dnf5 install -y \
        hyprland \
        hypridle \
        xdg-desktop-portal-hyprland

    dnf5 -y copr disable ashbuk/Hyprland-Fedora

    dnf5_guarded install -y \
        blueman \
        brightnessctl \
        grimshot \
        network-manager-applet \
        pavucontrol \
        swaylock \
        terminator \
        tesseract \
        waybar \
        wofi
fi
