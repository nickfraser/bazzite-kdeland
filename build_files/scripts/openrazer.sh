#!/bin/bash

set -ouex pipefail

SCRIPTDIR="$(dirname "$(realpath "$0")")"
source "${SCRIPTDIR}/dnf.sh"

if [[ BUILD_LAPTOP_OPENRAZER -eq "1" ]]; then
    readonly UBLUE_AKMODS_CERT=/etc/pki/akmods/certs/akmods-ublue.der
    readonly UBLUE_AKMODS_CERT_FINGERPRINT='4E:5C:68:47:4C:B1:33:FD:89:84:D9:59:97:62:CE:CE:91:00:C3:E6:CD:8A:97:09:AE:AA:BD:85:DD:9E:70:D1'
    readonly OPENRAZER_MODULES=(razeraccessory razerkbd razerkraken razermouse)

    mapfile -t kernel_releases < <(rpm -q --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core)
    if (( ${#kernel_releases[@]} != 1 )); then
        printf '%s\n' 'Expected exactly one installed kernel-core release.' >&2
        exit 1
    fi
    kernel_release="${kernel_releases[0]}"

    readonly kmod_package=kmod-openrazer
    rpm -q "${kmod_package}" ublue-os-akmods-addons
    ! rpm -q dkms
    ! rpm -q openrazer-kernel-modules-dkms

    mapfile -t common_packages < <(
        rpm -q --whatprovides --queryformat '%{NAME}\n' openrazer-kmod-common
    )
    (( ${#common_packages[@]} == 1 ))
    readonly common_package="${common_packages[0]}"
    common_evr="$(rpm -q --queryformat '%{EVR}\n' "${common_package}")"
    readonly common_evr
    readonly daemon_package="openrazer-daemon-${common_evr}"

    kmod_nevra="$(rpm -q --queryformat '%{NEVRA}\n' "${kmod_package}")"
    common_nevra="$(rpm -q --queryformat '%{NEVRA}\n' "${common_package}")"
    addons_nevra="$(rpm -q --queryformat '%{NEVRA}\n' ublue-os-akmods-addons)"
    readonly kmod_nevra common_nevra addons_nevra

    for module in "${OPENRAZER_MODULES[@]}"; do
        module_path="$(modinfo -k "${kernel_release}" -n "${module}")"
        [[ "${module_path}" == "/usr/lib/modules/${kernel_release}/"* || \
            "${module_path}" == "/lib/modules/${kernel_release}/"* ]]
        test "$(rpm -qf --queryformat '%{NAME}\n' "${module_path}")" = "${kmod_package}"
        read -r module_kernel _ < <(modinfo -k "${kernel_release}" -F vermagic "${module}")
        test "${module_kernel}" = "${kernel_release}"
        test "$(modinfo -k "${kernel_release}" -F signer "${module}")" = 'ublue kernel'
        modprobe --set-version "${kernel_release}" --show-depends "${module}" >/dev/null
    done

    test -f "${UBLUE_AKMODS_CERT}"
    test "$(rpm -qf --queryformat '%{NAME}\n' "${UBLUE_AKMODS_CERT}")" = 'ublue-os-akmods-addons'
    openssl x509 -inform DER -in "${UBLUE_AKMODS_CERT}" -noout -fingerprint -sha256 | \
        grep -Fqx "sha256 Fingerprint=${UBLUE_AKMODS_CERT_FINGERPRINT}"
    mapfile -t udev_rules < <(rpm -ql "${common_package}" | grep -E '/udev/rules.d/.*razer')
    (( ${#udev_rules[@]} > 0 ))
    grep -Eq 'GROUP="?plugdev"?' "${udev_rules[@]}"
    getent group plugdev >/dev/null

    # Keep Bazzite's matching kmod and only add its userspace daemon.
    dnf5_guarded install -y \
        --enable-repo=terra \
        --from-repo=terra \
        --exclude=dkms \
        "--exclude=${common_package}" \
        "--exclude=${kmod_package}" \
        --exclude=openrazer-kernel-modules-dkms \
        --exclude=ublue-os-akmods-addons \
        "${daemon_package}"

    readonly daemon=/usr/bin/openrazer-daemon
    readonly user_service=/usr/lib/systemd/user/openrazer-daemon.service
    readonly dbus_service=/usr/share/dbus-1/services/org.razer.service

    rpm -q openrazer-daemon
    test "$(rpm -q --queryformat '%{EVR}\n' openrazer-daemon)" = "${common_evr}"
    ! rpm -q dkms
    ! rpm -q openrazer-kernel-modules-dkms
    test "$(rpm -q --queryformat '%{NEVRA}\n' "${kmod_package}")" = "${kmod_nevra}"
    test "$(rpm -q --queryformat '%{NEVRA}\n' "${common_package}")" = "${common_nevra}"
    test "$(rpm -q --queryformat '%{NEVRA}\n' ublue-os-akmods-addons)" = "${addons_nevra}"
    test -x "${daemon}"
    test "$(rpm -qf --queryformat '%{NAME}\n' "${daemon}")" = 'openrazer-daemon'
    python3 -c 'import openrazer_daemon'
    test "$(rpm -qf --queryformat '%{NAME}\n' "${user_service}")" = 'openrazer-daemon'
    test "$(rpm -qf --queryformat '%{NAME}\n' "${dbus_service}")" = 'openrazer-daemon'
    grep -Eq '^ExecStart=.*/openrazer-daemon([[:space:]].*)?$' "${user_service}"
    grep -Fxq 'Name=org.razer' "${dbus_service}"
    grep -Fxq 'SystemdService=openrazer-daemon.service' "${dbus_service}"
fi
