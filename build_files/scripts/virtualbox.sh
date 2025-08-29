#!/bin/bash

# Script derived from: https://github.com/Preston159/bazzite-virtualbox

set -ouex pipefail

if [[ BUILD_VIRTUALBOX -eq "1" ]]; then
    # install dependencies required for VirtualBox kernel modules
    dnf install -y @development-tools kernel-headers kernel-devel dkms elfutils-libelf-devel qt5-qtx11extras
    # get latest version number of VirtualBox
    VIRTUALBOX_VER="$(curl -L https://download.virtualbox.org/virtualbox/LATEST.TXT)"
    SHORT_VER=$(echo ${VIRTUALBOX_VER} | awk -F . '{ printf "%s.%s\n", $1, $2 }')
    # Import VirtualBox GPG key (for repo/package signing)
    rpm --import https://www.virtualbox.org/download/oracle_vbox_2016.asc
    # Add the official VirtualBox repository (Fedora compatible)
    wget -P /etc/yum.repos.d/ https://download.virtualbox.org/virtualbox/rpm/fedora/virtualbox.repo
    # Install VirtualBox
    dnf install -y VirtualBox-${SHORT_VER}
#	Installing the extension pack doesn't seem to work
#    # Download Extension Pack (update version as needed)
#    EXT_PATH=/tmp/extpack.vbox-extpack
#    wget https://download.virtualbox.org/virtualbox/${VIRTUALBOX_VER}/Oracle_VirtualBox_Extension_Pack-${VIRTUALBOX_VER}.vbox-extpack -O ${EXT_PATH}
#    VBoxManage extpack install --replace ${EXT_PATH} <<EOF
#y
#EOF
#    VBoxManage list extpacks
	# Remove the repo
    rm -f /etc/yum.repos.d/virtualbox.repo
fi
