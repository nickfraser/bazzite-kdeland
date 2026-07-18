#!/bin/bash

set -ouex pipefail

SCRIPTDIR="$(dirname "$(realpath "$0")")"
source "${SCRIPTDIR}/dnf.sh"

if [[ BUILD_LAPTOP_OPENRAZER -eq "1" ]]; then
    readonly OPENRAZER_RPMS=/var/tmp/openrazer-rpms/rpms
    readonly OPENRAZER_DAEMON_VERSION=3.12.4-1.1
    readonly UBLUE_AKMODS_CERT=/etc/pki/akmods/certs/akmods-ublue.der
    readonly UBLUE_AKMODS_CERT_FINGERPRINT='4E:5C:68:47:4C:B1:33:FD:89:84:D9:59:97:62:CE:CE:91:00:C3:E6:CD:8A:97:09:AE:AA:BD:85:DD:9E:70:D1'

    mapfile -t kernel_releases < <(rpm -q --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core)
    if (( ${#kernel_releases[@]} != 1 )); then
        printf '%s\n' 'Expected exactly one installed kernel-core release.' >&2
        exit 1
    fi
    kernel_release="${kernel_releases[0]}"
    kernel_uname="${kernel_release%.*}"

    shopt -s nullglob
    kmod_rpms=(
        "${OPENRAZER_RPMS}"/ublue-os/ublue-os-akmods-addons*.rpm
        "${OPENRAZER_RPMS}"/common/openrazer-kmod-common*.rpm
        "${OPENRAZER_RPMS}"/kmods/kmod-openrazer-"${kernel_release}"-*.rpm
    )
    shopt -u nullglob

    if (( ${#kmod_rpms[@]} != 3 )); then
        printf '%s\n' 'Pinned UBlue artifact does not contain one exact-kernel OpenRazer RPM set.' >&2
        exit 1
    fi

    # These exact local RPMs are the only exception to the generic kmod guard.
    # Repository access is disabled so unresolved dependencies fail rather than
    # allowing the kmod install to change Bazzite packages.
    rpm --import "${SCRIPTDIR}/etc/pki/rpm-gpg/RPM-GPG-KEY-ublue-akmods"
    dnf5 install -y --disablerepo='*' "${kmod_rpms[@]}"

    install -Dm0644 "${SCRIPTDIR}/etc/yum.repos.d/hardware-razer.repo" \
        /etc/yum.repos.d/hardware-razer.repo
    trap 'rm -f /etc/yum.repos.d/hardware-razer.repo' EXIT
    dnf5_guarded install -y "openrazer-daemon-${OPENRAZER_DAEMON_VERSION}"

    module_path="$(find "/usr/lib/modules/${kernel_release}" -type f -name 'razerkbd.ko*' -print -quit)"
    test -n "${module_path}"
    rpm -qf "${module_path}" | grep -Eq '^kmod-openrazer-'
    modinfo -k "${kernel_release}" -F vermagic razerkbd | grep -Fq "${kernel_uname}"
    test -f "${UBLUE_AKMODS_CERT}"
    openssl x509 -inform DER -in "${UBLUE_AKMODS_CERT}" -noout -fingerprint -sha256 | \
        grep -Fqx "sha256 Fingerprint=${UBLUE_AKMODS_CERT_FINGERPRINT}"
    test "$(modinfo -k "${kernel_release}" -F signer razerkbd)" = 'ublue kernel'
    rpm -q openrazer-kmod-common openrazer-daemon ublue-os-akmods-addons
    ! rpm -q dkms
    rpm -q --whatprovides openrazer-kernel-modules-dkms | grep -Eq '^openrazer-kmod-common-'
    rpm -ql openrazer-kmod-common | grep -Eq '/udev/rules.d/.*razer'
    test -f /usr/lib/systemd/user/openrazer-daemon.service
    test -f /usr/share/dbus-1/services/org.razer.service
fi
