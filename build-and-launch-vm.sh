#!/usr/bin/env bash

set -eou pipefail

# --- Configuration & Defaults ---
VM_NAME="bazzite-local-vm"
VCPUS=4
RAM_MB=4096
DISK_FORMAT="qcow2"
# Note: Podman and bootc-image-builder need to be run as root to access the local storage cache
# easily and correctly build the image.
IMAGE_TAG="localhost/${VM_NAME}:latest"
BIB_IMAGE="quay.io/centos-bootc/bootc-image-builder:latest"
OUTPUT_DIR="${PWD}/output"
LIBVIRT_POOL="/var/lib/libvirt/images"

# --- Arguments & Flags ---
CONFIG_FILE=""
CREATE_DEFAULT_CONFIG=0

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Builds a bootc OCI image, converts it to a QCOW2 virtual machine disk,"
    echo "and launches it using KVM/libvirt."
    echo ""
    echo "Options:"
    echo "  --config <file.toml>    Use a custom config.toml for bootc-image-builder."
    echo "  --default-config        Create and use a default config.toml (user 'core', password 'password')."
    echo "  -h, --help              Show this help message."
    echo ""
    echo "Example:"
    echo "  $0 --default-config"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)
            if [[ -n "$2" ]]; then
                CONFIG_FILE=$(realpath "$2")
                shift 2
            else
                echo "Error: --config requires a file path."
                exit 1
            fi
            ;;
        --default-config)
            CREATE_DEFAULT_CONFIG=1
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

# --- Pre-flight Checks ---
echo "=> Checking dependencies..."
for cmd in podman virt-install virsh jq mktemp; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: Command '$cmd' is required but not installed."
        exit 1
    fi
done

# Ensure we are in the directory with the Containerfile
if [[ ! -f "Containerfile" ]]; then
    echo "Error: 'Containerfile' not found in the current directory."
    exit 1
fi

# --- Declarative Configuration ---
TMP_CONFIG=""
if [[ -n "$CONFIG_FILE" ]]; then
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Error: Config file '$CONFIG_FILE' not found."
        exit 1
    fi
    echo "=> Using custom config.toml: $CONFIG_FILE"
elif [[ $CREATE_DEFAULT_CONFIG -eq 1 ]]; then
    TMP_CONFIG=$(mktemp --suffix=".toml" "vm-config-XXXXXX")
    echo "=> Creating default config.toml at $TMP_CONFIG (user: core, pass: password)"
    cat <<EOF > "$TMP_CONFIG"
[customizations.user]
name = "core"
password = "password"
groups = ["wheel"]
EOF
    CONFIG_FILE=$(realpath "$TMP_CONFIG")
else
    echo "=> No config.toml provided. The VM will boot, but you may need a graphical first-boot wizard (if present in the image) to set a password."
fi

# --- 1. Build the OCI Image (Rootful) ---
echo "=> Building OCI image using Podman (requires sudo)..."
# Using same build args as build-local.sh where possible
BUILD_FROM_IMAGE="ghcr.io/ublue-os/bazzite-nvidia-open:stable"

sudo podman build \
    -f Containerfile \
    --tag="${IMAGE_TAG}" \
    --build-arg BUILD_FROM_IMAGE="${BUILD_FROM_IMAGE}" \
    --build-arg BUILD_SHELL=1 \
    --build-arg BUILD_HYPRLAND=1 \
    --build-arg BUILD_LAPTOP=1 \
    --build-arg BUILD_LAPTOP_CLAMSHELL=1 \
    --build-arg BUILD_LAPTOP_OPENRAZER=0 \
    --build-arg BUILD_CITRIX=0 \
    --build-arg BUILD_CITRIX_DEPS_ONLY=0 \
    --build-arg BUILD_DOCKER=1 \
    --build-arg BUILD_WINE=1 \
    --build-arg BUILD_KVM=1 \
    .

# --- 2. Generate the QCOW2 Disk ---
echo "=> Converting OCI image to QCOW2 using bootc-image-builder (requires sudo)..."
mkdir -p "${OUTPUT_DIR}"

BIB_ARGS=(
    --type "${DISK_FORMAT}"
    --use-librepo=True
    --rootfs=btrfs
)

# Setup volume mounts for the container
VOLUMES=(
    "-v" "/var/lib/containers/storage:/var/lib/containers/storage"
    "-v" "${OUTPUT_DIR}:/output"
)

# If a config file was provided or created, mount it
if [[ -n "$CONFIG_FILE" ]]; then
    VOLUMES+=("-v" "${CONFIG_FILE}:/config.toml:ro")
    # For bootc-image-builder we need to inject the config.toml file
    BIB_ARGS+=("--config" "/config.toml")
fi

sudo podman run \
    --rm \
    -it \
    --privileged \
    --pull=newer \
    --net=host \
    --security-opt label=type:unconfined_t \
    "${VOLUMES[@]}" \
    "${BIB_IMAGE}" \
    "${BIB_ARGS[@]}" \
    "${IMAGE_TAG}"

# Ensure output is accessible by the current user
sudo chown -R "$USER:$USER" "${OUTPUT_DIR}"

# Clean up temp config if we made one
if [[ -n "$TMP_CONFIG" && -f "$TMP_CONFIG" ]]; then
    rm -f "$TMP_CONFIG"
fi

QCOW2_FILE="${OUTPUT_DIR}/${DISK_FORMAT}/disk.${DISK_FORMAT}"
if [[ ! -f "${QCOW2_FILE}" ]]; then
    echo "Error: Failed to find generated QCOW2 file at ${QCOW2_FILE}"
    exit 1
fi

# --- 3. Provision and Launch KVM VM ---
echo "=> Provisioning KVM Virtual Machine..."

# Check if VM already exists and destroy/undefine it
if sudo virsh dominfo "${VM_NAME}" &>/dev/null; then
    echo "   VM '${VM_NAME}' already exists. Destroying and undefining it..."
    sudo virsh destroy "${VM_NAME}" &>/dev/null || true
    sudo virsh undefine "${VM_NAME}" --nvram --remove-all-storage &>/dev/null || true
fi

# Copy the disk image to libvirt's default pool
DEST_IMG="${LIBVIRT_POOL}/${VM_NAME}.${DISK_FORMAT}"
echo "   Copying disk image to ${DEST_IMG} (requires sudo)..."
sudo cp "${QCOW2_FILE}" "${DEST_IMG}"

# Set correct ownership and SELinux context for libvirt
sudo chown qemu:qemu "${DEST_IMG}" &>/dev/null || true # Best effort, might be libvirt-qemu on some distros
sudo chmod 644 "${DEST_IMG}"
if command -v restorecon &> /dev/null; then
    sudo restorecon -Rv "${DEST_IMG}" &>/dev/null || true
fi

echo "=> Launching VM using virt-install..."
# We use sudo for virt-install so it connects to the system qemu:///system URI properly
sudo virt-install \
    --name "${VM_NAME}" \
    --memory "${RAM_MB}" \
    --vcpus "${VCPUS}" \
    --disk "path=${DEST_IMG},format=${DISK_FORMAT},bus=virtio" \
    --os-variant "fedora-unknown" \
    --network default,model=virtio \
    --graphics spice \
    --video qxl \
    --channel spicevmc \
    --boot uefi \
    --import \
    --noautoconsole

echo ""
echo "========================================================================"
echo "Success! VM '${VM_NAME}' has been created and started."
echo "You can view the display using Virt-Manager or by running:"
echo "  sudo virt-viewer -c qemu:///system ${VM_NAME}"
echo "========================================================================"
