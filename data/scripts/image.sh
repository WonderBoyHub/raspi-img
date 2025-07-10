#!/usr/bin/env bash

set -eE

# Pop-OS Raspberry Pi Image Builder
# Enhanced image creation script with platform support

if [ -z "$1" -o -z "$2" -o ! -d "$3" -o -z "$4" -o -z "$5" -o -z "$6" ]
then
    echo "Usage: $0 [image] [mount] [debootstrap] [ubuntu_code] [ubuntu_mirror] [platform]" >&2
    echo "Platforms: pi4, pi5" >&2
    exit 1
fi

IMAGE="$(realpath "$1")"
MOUNT="$(realpath "$2")"
DEBOOTSTRAP="$(realpath "$3")"
UBUNTU_CODE="$4"
UBUNTU_MIRROR="$5"
PLATFORM="$6"

# Configuration paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$(dirname "$SCRIPT_DIR")"
COMMON_DIR="$DATA_DIR/common"
PLATFORM_DIR="$DATA_DIR/$PLATFORM"

echo "Building image for platform: $PLATFORM"
echo "Platform directory: $PLATFORM_DIR"

# Validate platform
if [ ! -d "$PLATFORM_DIR" ]; then
    echo "Error: Platform directory not found: $PLATFORM_DIR" >&2
    exit 1
fi

if [ ! -f "$PLATFORM_DIR/boot/firmware/config.txt" ]; then
    echo "Error: Platform config.txt not found: $PLATFORM_DIR/boot/firmware/config.txt" >&2
    exit 1
fi

function cleanup {
    set +x
    echo "Cleaning up..."

    # Unmount all mounted partitions and bind mounts
    if [ -n "$(mount | grep "${MOUNT}")" ]
    then
        echo "Unmounting partitions..."
        # Cleanup chroot bind mounts first
        umount "${MOUNT}/dev/pts" 2>/dev/null || true
        umount "${MOUNT}/dev" 2>/dev/null || true
        umount "${MOUNT}/sys" 2>/dev/null || true
        umount "${MOUNT}/proc" 2>/dev/null || true
        # Then unmount the main partitions
        umount "${MOUNT}/boot/firmware" 2>/dev/null || true
        umount "${MOUNT}" 2>/dev/null || true
    fi

    # Ensure there are no mounted partitions
    if [ -n "$(mount | grep "${MOUNT}")" ]
    then
        echo "Warning: ${MOUNT} still mounted" >&2
        # Don't fail here, just warn
    fi

    # Remove device mapper mappings
    if [ -n "$(losetup --associated "${IMAGE}" 2>/dev/null)" ]; then
        LODEV="$(losetup --associated "${IMAGE}" 2>/dev/null | cut -d ':' -f1 | head -n1)"
        if [ -n "$LODEV" ]; then
            echo "Removing device mapper mappings for: $LODEV"
            kpartx -d "$LODEV" 2>/dev/null || true
        fi
    fi

    # Detach all loopback devices
    losetup --associated "${IMAGE}" 2>/dev/null | cut -d ':' -f1 | while read LODEV
    do
        if [ -n "$LODEV" ]; then
            echo "Detaching loopback device: $LODEV"
            losetup --detach "${LODEV}" 2>/dev/null || true
        fi
    done

    # Final check for attached loopback devices
    if [ -n "$(losetup --associated "${IMAGE}" 2>/dev/null)" ]; then
        echo "Warning: Some loopback devices may still be attached to ${IMAGE}" >&2
    fi
}

# Run cleanup on error
trap cleanup ERR

# Run cleanup prior to the script
cleanup

# Remove old mount
rm --recursive --force --one-file-system "${MOUNT}" 2>/dev/null || true

# Remove old image
rm --recursive --force --verbose "${IMAGE}" 2>/dev/null || true

set -x

echo "Creating ${PLATFORM} image..."

# Allocate image (8GiB)
fallocate --verbose --length 8GiB "${IMAGE}"

# Partition image
parted "${IMAGE}" mktable msdos
parted "${IMAGE}" mkpart primary fat32 1MiB 256MiB
parted "${IMAGE}" set 1 boot on
parted "${IMAGE}" mkpart primary ext4 256MiB 100%

# Loopback mount image file
LODEV="$(losetup --find --show "${IMAGE}")"
echo "Using loopback device: $LODEV"

# Create partition device mappings using kpartx
echo "Creating partition device mappings..."
kpartx -a "${LODEV}"
sleep 2

# Get the device mapper names
BOOT_DEV="/dev/mapper/$(basename "${LODEV}")p1"
ROOT_DEV="/dev/mapper/$(basename "${LODEV}")p2"

echo "Boot device: $BOOT_DEV"
echo "Root device: $ROOT_DEV"

# Verify partition devices exist
if [ ! -b "$BOOT_DEV" ] || [ ! -b "$ROOT_DEV" ]; then
    echo "Error: Partition devices not found"
    echo "Available device mappings:"
    ls -la /dev/mapper/
    echo "Available loop devices:"
    ls -la /dev/loop*
    exit 1
fi

# Format boot partition
echo "Formatting boot partition..."
mkfs.vfat -n system-boot "$BOOT_DEV"

# Format root partition
echo "Formatting root partition..."
mkfs.ext4 -L writable "$ROOT_DEV"

# Create mount directory
mkdir -pv "${MOUNT}"

# Mount root partition
mount "$ROOT_DEV" "${MOUNT}"

echo "Copying debootstrap to image..."
# Copy debootstrap
rsync \
    --archive \
    --acls \
    --hard-links \
    --numeric-ids \
    --sparse \
    --whole-file \
    --xattrs \
    --stats \
    "${DEBOOTSTRAP}/" "${MOUNT}/"

echo "Copying common configuration files..."
# Copy common configuration files
if [ -d "${COMMON_DIR}/etc" ]; then
    rsync \
        --recursive \
        --verbose \
        "${COMMON_DIR}/etc/" \
        "${MOUNT}/etc/"
fi

echo "Copying platform-specific configuration files..."
# Copy platform-specific configuration files
if [ -d "${PLATFORM_DIR}/etc" ]; then
    rsync \
        --recursive \
        --verbose \
        "${PLATFORM_DIR}/etc/" \
        "${MOUNT}/etc/"
fi

# Mount boot partition
mkdir -p "${MOUNT}/boot/firmware"
mount "$BOOT_DEV" "${MOUNT}/boot/firmware"

echo "Copying platform-specific firmware files..."
# Copy platform-specific firmware files
rsync \
    --recursive \
    --verbose \
    "${PLATFORM_DIR}/boot/firmware/" \
    "${MOUNT}/boot/firmware/"

# Copy chroot script
cp -v "${SCRIPT_DIR}/chroot.sh" "${MOUNT}/chroot.sh"

# Make chroot script executable
chmod +x "${MOUNT}/chroot.sh"

echo "Running chroot script for $PLATFORM..."

# Prepare chroot environment
echo "Preparing chroot environment..."

# Mount essential filesystems for chroot
mount --bind /proc "${MOUNT}/proc"
mount --bind /sys "${MOUNT}/sys"
mount --bind /dev "${MOUNT}/dev"
mount --bind /dev/pts "${MOUNT}/dev/pts"

# Copy QEMU static binary for ARM64 emulation in chroot
if [ ! -f "${MOUNT}/usr/bin/qemu-aarch64-static" ]; then
    echo "Copying QEMU static binary for chroot..."
    cp /usr/bin/qemu-aarch64-static "${MOUNT}/usr/bin/"
fi

# Set up basic DNS resolution
mkdir -p "${MOUNT}/run/systemd/resolve"
echo "nameserver 1.1.1.1" > "${MOUNT}/run/systemd/resolve/stub-resolv.conf"

# Run chroot script
PLATFORM="${PLATFORM}" chroot "${MOUNT}" bash /chroot.sh

# Cleanup chroot mounts
echo "Cleaning up chroot mounts..."
umount "${MOUNT}/dev/pts" 2>/dev/null || true
umount "${MOUNT}/dev" 2>/dev/null || true
umount "${MOUNT}/sys" 2>/dev/null || true
umount "${MOUNT}/proc" 2>/dev/null || true

# Remove chroot script
rm -v "${MOUNT}/chroot.sh"

echo "Image creation completed successfully for $PLATFORM"

# Run cleanup after the script
cleanup

echo "Final image: ${IMAGE}"
echo "Image size: $(du -h "${IMAGE}" | cut -f1)"
