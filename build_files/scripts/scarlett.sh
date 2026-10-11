#!/bin/bash

set -ouex pipefail

SCRIPTDIR="$(dirname "$(realpath "$0")")"
source "${SCRIPTDIR}/dnf.sh"

if [[ "${BUILD_SCARLETT:-0}" != "1" ]]; then
    exit 0
fi

# jq is only needed by the enabled feature. curl and rpm come with Bazzite.
if ! command -v jq >/dev/null; then
    dnf5_guarded install -y jq
fi

ARCH="$(rpm --eval '%{_arch}')"
FEDORA="$(rpm --eval '%{fedora}')"
DOWNLOAD_DIR="$(mktemp -d)"
trap 'rm -rf -- "${DOWNLOAD_DIR}"' EXIT

fetch() {
    curl --fail --silent --show-error --location \
        --retry 3 --connect-timeout 20 --max-time 180 \
        --proto '=https' --proto-redir '=https' "$@"
}

download_rpm() {
    local package="$1" allow_prerelease="$2"
    local page=1 page_file release_file asset_file asset_name url digest checksum_file
    local rpm_file rpm_name rpm_arch rpm_release

    # Read all pages: a stable release may be behind many newer prereleases.
    while :; do
        page_file="${DOWNLOAD_DIR}/${package}-page-${page}.json"
        fetch "https://api.github.com/repos/geoffreybennett/${package}/releases?per_page=100&page=${page}" \
            -o "${page_file}"
        jq -e 'type == "array"' "${page_file}" >/dev/null
        if [[ "$(jq 'length' "${page_file}")" -lt 100 ]]; then
            break
        fi
        page=$((page + 1))
    done

    release_file="${DOWNLOAD_DIR}/${package}-release.json"
    # GitHub's prerelease flag is authoritative, even for beta-named GUI tags.
    # FCP currently has no stable release; only that project gets an exception.
    jq -se --argjson allow_prerelease "${allow_prerelease}" '
        add | map(select(.draft == false)) |
        . as $releases | map(select(.prerelease == false)) |
        if length > 0 then max_by([.published_at, .id])
        elif $allow_prerelease and ($releases | length > 0)
        then $releases | max_by([.published_at, .id])
        else error("No eligible published release") end
    ' "${DOWNLOAD_DIR}/${package}"-page-*.json > "${release_file}"

    jq -r '"Scarlett release: \(.html_url) (prerelease=\(.prerelease))"' "${release_file}"
    asset_file="${DOWNLOAD_DIR}/${package}-asset.json"
    # Require one binary RPM for this architecture (or noarch), built for this
    # Fedora release or without a Fedora suffix. Never search older releases.
    jq -e --arg package "${package}" --arg arch "${ARCH}" --arg fedora "${FEDORA}" '
        [.assets[] | select(.state == "uploaded") |
            select(.name | test("^" + $package + "-[0-9][A-Za-z0-9._+~%-]*\\.(" + $arch + "|noarch)\\.rpm$")) |
            select((.name | test("\\.fc[0-9]+\\." ) | not) or
                (.name | contains(".fc" + $fedora + ".")))] |
        if length == 1 then .[0]
        else error("Expected exactly one compatible RPM in selected release") end
    ' "${release_file}" > "${asset_file}"

    asset_name="$(jq -er '.name' "${asset_file}")"
    url="$(jq -er '.browser_download_url' "${asset_file}")"
    # Restrict release assets to the official project, including checksums.
    [[ "${url}" == "https://github.com/geoffreybennett/${package}/releases/download/"* ]]
    rpm_file="${DOWNLOAD_DIR}/${asset_name}"
    echo "Scarlett RPM: ${url}"
    fetch "${url}" -o "${rpm_file}"

    digest="$(jq -r '.digest // empty' "${asset_file}")"
    if [[ -z "${digest}" ]]; then
        # Older release assets may lack API digests; use a release checksum
        # file if one exists. Match only the selected RPM's entry below.
        checksum_file="${DOWNLOAD_DIR}/${package}-checksums.txt"
        url="$(jq -er --arg name "${asset_name}" '
            [.assets[] | select(.state == "uploaded") |
                select(.name == ($name + ".sha256") or .name == "SHA256SUMS" or
                    .name == "SHA256SUMS.txt" or .name == "checksums.sha256")] |
            if length == 0 then "none"
            elif length == 1 then .[0].browser_download_url
            else error("Ambiguous release checksum files") end
        ' "${release_file}")"
        if [[ "${url}" != "none" ]]; then
            [[ "${url}" == "https://github.com/geoffreybennett/${package}/releases/download/"* ]]
            fetch "${url}" -o "${checksum_file}"
            digest="$(jq -Rrse --arg name "${asset_name}" '
                [split("\n")[] | scan("^([A-Fa-f0-9]{64}) [ *](.+)$") |
                    select(.[1] == $name or .[1] == ("./" + $name)) | .[0]] |
                if length == 1 then "sha256:" + .[0]
                else error("Missing or ambiguous RPM checksum") end
            ' "${checksum_file}")"
        fi
    fi
    if [[ -n "${digest}" ]]; then
        [[ "${digest}" =~ ^sha256:[A-Fa-f0-9]{64}$ ]]
        printf '%s  %s\n' "${digest#sha256:}" "${rpm_file}" | sha256sum --check --strict
    else
        echo "No release SHA-256 checksum available for ${asset_name}; checking RPM integrity only."
    fi
    # Also checks signatures when present, using the image's trusted RPM keys.
    # Unsigned upstream RPMs still get their internal digests checked.
    rpm --checksig "${rpm_file}"

    rpm_name="$(rpm -qp --queryformat '%{NAME}' "${rpm_file}")"
    rpm_arch="$(rpm -qp --queryformat '%{ARCH}' "${rpm_file}")"
    rpm_release="$(rpm -qp --queryformat '%{RELEASE}' "${rpm_file}")"
    [[ "${rpm_name}" == "${package}" ]]
    [[ "${rpm_arch}" == "${ARCH}" || "${rpm_arch}" == "noarch" ]]
    if [[ "${rpm_release}" =~ \.fc([0-9]+)($|\.) ]]; then
        [[ "${BASH_REMATCH[1]}" == "${FEDORA}" ]]
    fi
    rpm -qp --queryformat 'Scarlett selected package: %{NAME} %{EPOCHNUM}:%{VERSION}-%{RELEASE}.%{ARCH}\n' "${rpm_file}"
    RPMS+=("${rpm_file}")
}

RPMS=()
download_rpm fcp-support true
download_rpm scarlett4-firmware false
download_rpm alsa-scarlett-gui false

# One guarded transaction resolves dependencies without replacing Bazzite's
# kernel/graphics stack. Do not start services or flash firmware in the build.
dnf5_guarded install -y "${RPMS[@]}"
rpm -q --queryformat 'Scarlett installed package: %{NAME} %{EPOCHNUM}:%{VERSION}-%{RELEASE}.%{ARCH}\n' \
    fcp-support scarlett4-firmware alsa-scarlett-gui
