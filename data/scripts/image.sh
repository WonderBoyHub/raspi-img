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

    # Unmount all mounted partitions
    if [ -n "$(mount | grep "${MOUNT}")" ]
    then
        echo "Unmounting partitions..."
        umount "${MOUNT}/boot/firmware" 2>/dev/null || true
        umount "${MOUNT}" 2>/dev/null || true
    fi

    # Ensure there are no mounted partitions
    if [ -n "$(mount | grep "${MOUNT}")" ]
    then
        echo "Warning: ${MOUNT} still mounted" >&2
        # Don't fail here, just warn
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
LODEV="$(losetup --find --show --partscan "${IMAGE}")"
echo "Using loopback device: $LODEV"

# Wait for partition device nodes to appear
echo "Waiting for partition device nodes..."
for i in {1..30}; do
    if [ -b "${LODEV}p1" ] && [ -b "${LODEV}p2" ]; then
        echo "Partition device nodes found"
        break
    fi
    
    if [ $i -eq 30 ]; then
        echo "Partition device nodes not found after 30 seconds"
        echo "Available devices:"
        ls -la /dev/loop*
        # Try to force partition table re-read
        partprobe "${LODEV}" 2>/dev/null || true
        sleep 1
        if [ ! -b "${LODEV}p1" ] || [ ! -b "${LODEV}p2" ]; then
            echo "Error: Partition device nodes ${LODEV}p1 and ${LODEV}p2 not found"
            exit 1
        fi
    fi
    
    echo "Waiting for partitions... ($i/30)"
    sleep 1
done

# Format boot partition
echo "Formatting boot partition..."
mkfs.vfat -n system-boot "${LODEV}p1"

# Format root partition
echo "Formatting root partition..."
mkfs.ext4 -L writable "${LODEV}p2"

# Create mount directory
mkdir -pv "${MOUNT}"

# Mount root partition
mount "${LODEV}p2" "${MOUNT}"

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
mount "${LODEV}p1" "${MOUNT}/boot/firmware"

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
# Run chroot script in container
systemd-nspawn \
    --machine=pop-os-${PLATFORM} \
    --resolv-conf=off \
    --directory="${MOUNT}" \
    --setenv=PLATFORM="${PLATFORM}" \
    bash /chroot.sh

# Remove chroot script
rm -v "${MOUNT}/chroot.sh"

echo "Image creation completed successfully for $PLATFORM"

# Run cleanup after the script
cleanup

echo "Final image: ${IMAGE}"
echo "Image size: $(du -h "${IMAGE}" | cut -f1)"
