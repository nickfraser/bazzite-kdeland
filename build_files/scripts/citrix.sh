#!/bin/bash

set -ouex pipefail

SCRIPTDIR="$(dirname "$(realpath "$0")")"
source "${SCRIPTDIR}/dnf.sh"

if [[ BUILD_CITRIX -eq "1" ]]; then
    # I'm checking for a checksum match, because I don't trust this script - too many assumption built-in
    CHECKSUM="14f468ac47f14170d809eac4cf813fe7c88c394fea2317b543dc28b13135f79a"
    VERSION="26.01.0.150-0"
    DL_TARGET=/tmp/citrix_workspace_x86_64.rpm
    # Scrape website to get the right download link
    url=$(wget -O - https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html | sed -ne '/ICAClient-rhel.*/ s/<a .* rel="\(.*\)" id="downloadcomponent.*">/https:\1/p' | sed -e 's/\r//g')
    DL_VERSION=$(echo ${url} | grep -Po 'rhel-.*.rpm' | sed 's/rhel-//g' | sed 's/.x86_64.rpm//g')
    # Download the file
    wget ${url} -O ${DL_TARGET}
    DL_CHECKSUM=$(sha256sum ${DL_TARGET} | awk '{print $1}')
    if [[ "${CHECKSUM}" == "${DL_CHECKSUM}" ]]; then
        if [[ BUILD_CITRIX_DEPS_ONLY -eq "1" ]]; then
            # Extract dependencies from rpm and install them (TODO: keep version constraints?)
            mapfile -t deps < <(rpm -qRp ${DL_TARGET} | awk '{print $1}' | grep -Ev '(/bin/sh|rpmlib)' | sort -u)
            if [[ "${#deps[@]}" -gt 0 ]]; then
                dnf5_guarded install -y "${deps[@]}"
            fi
        else
            rm /opt
            mkdir -p /usr/share/factory/opt
            ln -s /usr/share/factory/opt /opt # See: https://github.com/ublue-os/image-template/pull/100
            dnf5_guarded install -y ${DL_TARGET}
            rm /opt
            ln -s /var/opt /opt
        fi
    else
        echo "Checksum does not match!"
        echo "Expected: ${CHECKSUM}, Found: ${DL_CHECKSUM}"
        echo "Expected: ${VERSION}, Found: ${DL_VERSION}"
        exit 1
    fi
fi
