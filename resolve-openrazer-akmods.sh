#!/bin/bash

set -euo pipefail

if (( $# != 1 )); then
    printf 'Usage: %s <bazzite-base-image>\n' "${0##*/}" >&2
    exit 2
fi

readonly base_image="$1"
readonly akmods_repository='ghcr.io/ublue-os/akmods'

podman pull --retry 3 "${base_image}" >&2

mapfile -t kernel_releases < <(
    podman run --rm --entrypoint /usr/bin/rpm "${base_image}" \
        -q --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core
)
if (( ${#kernel_releases[@]} != 1 )); then
    printf 'Expected exactly one kernel-core release in %s.\n' "${base_image}" >&2
    exit 1
fi
readonly kernel_release="${kernel_releases[0]}"

if [[ ! "${kernel_release}" =~ \.fc([0-9]+)\. ]]; then
    printf 'Cannot derive the Fedora release from kernel %s.\n' "${kernel_release}" >&2
    exit 1
fi
readonly fedora_release="${BASH_REMATCH[1]}"
readonly tagged_image="${akmods_repository}:ogc-${fedora_release}-${kernel_release}"

podman pull --retry 3 "${tagged_image}" >&2

artifact_kernel="$(
    podman image inspect --format '{{ index .Labels "ostree.linux" }}' "${tagged_image}"
)"
if [[ "${artifact_kernel}" != "${kernel_release}" ]]; then
    printf 'Akmods artifact kernel %s does not match base kernel %s.\n' \
        "${artifact_kernel}" "${kernel_release}" >&2
    exit 1
fi

artifact_digest="$(podman image inspect --format '{{ .Digest }}' "${tagged_image}")"
if [[ ! "${artifact_digest}" =~ ^sha256:[0-9a-f]{64}$ ]]; then
    printf 'Could not resolve an immutable digest for %s.\n' "${tagged_image}" >&2
    exit 1
fi
readonly artifact_image="${akmods_repository}@${artifact_digest}"

printf 'Base kernel: %s\n' "${kernel_release}" >&2
printf 'OpenRazer akmods tag: %s\n' "${tagged_image}" >&2
printf 'OpenRazer akmods digest: %s\n' "${artifact_image}" >&2
printf '%s\n' "${artifact_image}"
