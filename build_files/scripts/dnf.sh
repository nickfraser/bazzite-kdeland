#!/bin/bash

# Keep Bazzite's kernel and graphics stack aligned with the base image.
readonly DNF5_BAZZITE_GUARD_ARGS=(
    "--setopt=allow_vendor_change=0"
    "--exclude=kernel*"
    "--exclude=akmod-*"
    "--exclude=kmod-*"
    "--exclude=*nvidia*"
    "--exclude=libva-nvidia-driver"
    "--exclude=mesa*"
    "--exclude=libdrm*"
)

dnf5_guarded() {
    local subcommand="$1"
    shift

    dnf5 "$subcommand" "${DNF5_BAZZITE_GUARD_ARGS[@]}" "$@"
}
