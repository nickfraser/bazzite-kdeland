#!/usr/bin/env bash

set -euo pipefail

# --- Configuration & Defaults ---
VM_NAME="bazzite-local-vm"
IMAGE_TAG="localhost/${VM_NAME}:latest"
OUTPUT_DIR="${PWD}/output"
DISK_FORMAT="qcow2"

USE_ROOTLESS=0

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Cleans up the VM, disk images, and build artifacts created by build-and-launch-vm.sh."
    echo ""
    echo "Options:"
    echo "  --rootless              Run cleanup in rootless mode (use if VM was created with --rootless)."
    echo "  -h, --help              Show this help message."
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rootless)
            USE_ROOTLESS=1
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

if [[ $USE_ROOTLESS -eq 1 ]]; then
    SUDO_CMD=""
    LIBVIRT_URI="qemu:///session"
    LIBVIRT_POOL="${HOME}/.local/share/libvirt/images"
    echo "=> Running cleanup in ROOTLESS mode."
else
    SUDO_CMD="sudo"
    LIBVIRT_URI="qemu:///system"
    LIBVIRT_POOL="/var/lib/libvirt/images"
    echo "=> Running cleanup in SYSTEM mode (requires sudo)."
fi

DEST_IMG="${LIBVIRT_POOL}/${VM_NAME}.${DISK_FORMAT}"

echo "=> Stopping and removing VM '${VM_NAME}'..."
if virsh --connect "${LIBVIRT_URI}" dominfo "${VM_NAME}" &>/dev/null; then
    virsh --connect "${LIBVIRT_URI}" destroy "${VM_NAME}" &>/dev/null || true
    virsh --connect "${LIBVIRT_URI}" undefine "${VM_NAME}" --nvram --remove-all-storage &>/dev/null || true
    echo "   VM '${VM_NAME}' stopped and undefined."
else
    echo "   VM '${VM_NAME}' does not exist or is already removed."
fi

echo "=> Removing disk image from libvirt pool..."
if [[ -f "${DEST_IMG}" ]]; then
    $SUDO_CMD rm -f "${DEST_IMG}"
    echo "   Removed ${DEST_IMG}"
else
    echo "   Disk image ${DEST_IMG} not found."
fi

echo "=> Removing local build output directory..."
if [[ -d "${OUTPUT_DIR}" ]]; then
    $SUDO_CMD rm -rf "${OUTPUT_DIR}"
    echo "   Removed ${OUTPUT_DIR}"
else
    echo "   Output directory ${OUTPUT_DIR} not found."
fi

echo "=> Removing Podman container image..."
if $SUDO_CMD podman image exists "${IMAGE_TAG}"; then
    $SUDO_CMD podman rmi -f "${IMAGE_TAG}"
    echo "   Removed image ${IMAGE_TAG}"
else
    echo "   Image ${IMAGE_TAG} not found."
fi

echo ""
echo "========================================================================"
echo "Cleanup complete!"
echo "========================================================================"
