#!/bin/bash

set -ouex pipefail

SCRIPTDIR="$(dirname "$(realpath "$0")")"
source "${SCRIPTDIR}/dnf.sh"

readonly CITRIX_INSTALL_METHOD="noscripts"

if [[ BUILD_CITRIX -eq "1" ]]; then
    # I'm checking for a checksum match, because I don't trust this script - too many assumption built-in
    CHECKSUM="b3203d18d43299ecdf497ec93371c83da9a431edd29a930cdcffc55e52e82d16"
    VERSION="26.04.0.105-0"
    DL_TARGET=/tmp/citrix_workspace_x86_64.rpm
    # Match the RPM URL directly so extra flavor segments like "gcc-8" do not break parsing.
    url=$(wget -O - https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html | tr -d '\r' | grep -oPm 1 '(?<=")//[^"]*ICAClient-rhel[^"]*\.x86_64\.rpm\?__[^"]*')
    url="https:${url}"

    rpm_name="${url%%\?*}"
    rpm_name="${rpm_name##*/}"
    if [[ "${rpm_name}" =~ ^ICAClient-rhel-.*-([0-9]+(\.[0-9]+)*-[0-9]+)\.x86_64\.rpm$ ]]; then
        DL_VERSION="${BASH_REMATCH[1]}"
    else
        echo "Unable to extract Citrix version from ${rpm_name}"
        exit 1
    fi

    # Download the file
    wget "${url}" -O "${DL_TARGET}"
    DL_CHECKSUM=$(sha256sum ${DL_TARGET} | awk '{print $1}')
    if [[ "${CHECKSUM}" == "${DL_CHECKSUM}" ]]; then
        if [[ BUILD_CITRIX_DEPS_ONLY -eq "1" || "${CITRIX_INSTALL_METHOD}" == "noscripts" ]]; then
            # Install dependencies separately when skipping Citrix RPM scriptlets.
            mapfile -t deps < <(rpm -qRp "${DL_TARGET}" | awk '{print $1}' | grep -Ev '(/bin/sh|rpmlib)' | sort -u)
            if [[ "${#deps[@]}" -gt 0 ]]; then
                dnf5_guarded install -y "${deps[@]}"
            fi
        fi

        if [[ BUILD_CITRIX_DEPS_ONLY -ne "1" ]]; then
            rm /opt
            mkdir -p /usr/share/factory/opt
            ln -s /usr/share/factory/opt /opt # See: https://github.com/ublue-os/image-template/pull/100

            if [[ "${CITRIX_INSTALL_METHOD}" == "noscripts" ]]; then
                rpm -i --nodeps --noscripts "${DL_TARGET}"
            else
                # Legacy path retained for reference; Citrix RPM scriptlets can hang in CI.
                dnf5_guarded install -y "${DL_TARGET}"
            fi

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
