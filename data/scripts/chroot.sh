#!/usr/bin/env bash

set -ex

# Pop-OS Raspberry Pi Image Builder
# Enhanced chroot script with platform support

# Get platform from environment (set by image.sh)
PLATFORM="${PLATFORM:-pi4}"

echo "Installing packages for platform: $PLATFORM"

# Set up DNS
if [ ! -f /run/systemd/resolve/stub-resolv.conf ]
then
    mkdir -p /run/systemd/resolve
    echo "nameserver 1.1.1.1" > /run/systemd/resolve/stub-resolv.conf
fi

# Fix any interrupted dpkg operations first
echo "Checking and fixing dpkg state..."
dpkg --configure -a || {
    echo "Warning: dpkg configuration had issues, continuing..."
}

# Update and upgrade prior to installing packages
echo "Updating package lists..."
apt-get update || {
    echo "Warning: Some repositories may not be available for ARM64"
    echo "Continuing with available packages..."
}

echo "Upgrading existing packages..."
apt-get dist-upgrade --yes \
    -o Dpkg::Options::="--force-confnew"

# Install distribution packages
# Note: pop-desktop-raspi doesn't exist for ARM64, using alternative packages
echo "Installing desktop environment packages..."

# Check available disk space
echo "Current disk usage:"
df -h / || echo "Could not check disk space"

# Ensure dpkg is in a consistent state before each major installation
dpkg --configure -a || echo "dpkg configure completed with warnings"

# Try to install the full desktop environment
if apt-get install --yes \
    -o Dpkg::Options::="--force-confnew" \
    ubuntu-desktop-minimal \
    gnome-shell \
    gnome-tweaks \
    gnome-extensions-app \
    firefox \
    ubuntu-drivers-common; then
    echo "Full desktop environment installed successfully"
    
    # Clean up package cache to free space
    echo "Cleaning package cache after full installation..."
    apt-get clean
    echo "Disk usage after cleanup:"
    df -h / || echo "Could not check disk space"
else
    echo "Warning: Some desktop packages may not be available"
    echo "Installing minimal desktop environment..."
    
    # Clean up any partial downloads first
    apt-get clean
    
    # Fix dpkg state again before fallback
    dpkg --configure -a || echo "dpkg configure completed with warnings"
    
    if apt-get install --yes \
        -o Dpkg::Options::="--force-confnew" \
        ubuntu-desktop-minimal \
        firefox; then
        echo "Minimal desktop environment installed successfully"
    else
        echo "Installing basic packages only..."
        
        # Fix dpkg state one more time
        dpkg --configure -a || echo "dpkg configure completed with warnings"
        
        apt-get install --yes \
            -o Dpkg::Options::="--force-confnew" \
            gnome-shell \
            gdm3 \
            ubuntu-drivers-common || {
            echo "Warning: Even basic package installation had issues"
            echo "Continuing with whatever packages were successfully installed..."
        }
    fi
fi

# Install platform-specific packages
echo "Preparing for platform-specific package installation..."
echo "Current disk usage before platform packages:"
df -h / || echo "Could not check disk space"

# Clean cache and fix dpkg state before platform packages
apt-get clean
dpkg --configure -a || echo "dpkg configure completed with warnings"

case "$PLATFORM" in
    pi5)
        echo "Installing Raspberry Pi 5 specific packages..."
        # Install Pi 5 specific firmware and drivers
        apt-get install --yes \
            -o Dpkg::Options::="--force-confnew" \
            linux-firmware-raspi \
            linux-raspi \
            u-boot-rpi || {
            echo "Warning: Some Pi 5 packages failed to install"
            dpkg --configure -a || echo "dpkg configure completed with warnings"
        }
        ;;
    pi4)
        echo "Installing Raspberry Pi 4 specific packages..."
        # Install Pi 4 specific packages (default)
        apt-get install --yes \
            -o Dpkg::Options::="--force-confnew" \
            linux-firmware-raspi \
            linux-raspi \
            u-boot-rpi || {
            echo "Warning: Some Pi 4 packages failed to install"
            dpkg --configure -a || echo "dpkg configure completed with warnings"
        }
        ;;
    *)
        echo "Unknown platform: $PLATFORM, using default packages"
        apt-get install --yes \
            -o Dpkg::Options::="--force-confnew" \
            linux-firmware-raspi \
            linux-raspi \
            u-boot-rpi || {
            echo "Warning: Some default packages failed to install"
            dpkg --configure -a || echo "dpkg configure completed with warnings"
        }
        ;;
esac

# Clean up after platform packages
echo "Cleaning up after platform package installation..."
apt-get clean
echo "Disk usage after platform packages:"
df -h / || echo "Could not check disk space"

# Clean apt caches
apt-get autoremove --purge --yes
apt-get autoclean
apt-get clean

# Final dpkg configuration to ensure everything is properly set up
echo "Final dpkg configuration check..."
dpkg --configure -a || echo "Final dpkg configure completed with warnings"

# Copy firmware to boot partition
echo "Copying firmware files..."
cp --verbose /boot/initrd.img /boot/firmware/
cp --verbose /boot/vmlinuz /boot/firmware/

# Copy device tree files
echo "Copying device tree files..."
cp --verbose /lib/firmware/*-raspi/device-tree/broadcom/* /boot/firmware/
cp --recursive --verbose /lib/firmware/*-raspi/device-tree/overlays/ /boot/firmware/

# Copy firmware files
echo "Copying additional firmware..."
cp --verbose /usr/lib/linux-firmware-raspi/* /boot/firmware/

# Platform-specific firmware and U-Boot handling
case "$PLATFORM" in
    pi5)
        echo "Configuring Raspberry Pi 5 specific firmware..."
        # Copy Pi 5 specific U-Boot
        if [ -f /usr/lib/u-boot/rpi_5/u-boot.bin ]; then
            cp --verbose /usr/lib/u-boot/rpi_5/u-boot.bin /boot/firmware/uboot_rpi_5.bin
        fi
        # Copy generic ARM64 U-Boot as fallback
        if [ -f /usr/lib/u-boot/rpi_arm64/u-boot.bin ]; then
            cp --verbose /usr/lib/u-boot/rpi_arm64/u-boot.bin /boot/firmware/uboot_rpi_arm64.bin
        fi
        # Copy other platform U-Boot files for compatibility
        if [ -f /usr/lib/u-boot/rpi_4/u-boot.bin ]; then
            cp --verbose /usr/lib/u-boot/rpi_4/u-boot.bin /boot/firmware/uboot_rpi_4.bin
        fi
        ;;
    pi4)
        echo "Configuring Raspberry Pi 4 specific firmware..."
        # Copy Pi 4 specific U-Boot
        if [ -f /usr/lib/u-boot/rpi_4/u-boot.bin ]; then
            cp --verbose /usr/lib/u-boot/rpi_4/u-boot.bin /boot/firmware/uboot_rpi_4.bin
        fi
        # Copy generic ARM64 U-Boot as fallback
        if [ -f /usr/lib/u-boot/rpi_arm64/u-boot.bin ]; then
            cp --verbose /usr/lib/u-boot/rpi_arm64/u-boot.bin /boot/firmware/uboot_rpi_arm64.bin
        fi
        # Copy Pi 3 U-Boot for compatibility
        if [ -f /usr/lib/u-boot/rpi_3/u-boot.bin ]; then
            cp --verbose /usr/lib/u-boot/rpi_3/u-boot.bin /boot/firmware/uboot_rpi_3.bin
        fi
        ;;
    *)
        echo "Configuring default firmware..."
        # Copy all available U-Boot files
        if [ -f /usr/lib/u-boot/rpi_3/u-boot.bin ]; then
            cp --verbose /usr/lib/u-boot/rpi_3/u-boot.bin /boot/firmware/uboot_rpi_3.bin
        fi
        if [ -f /usr/lib/u-boot/rpi_4/u-boot.bin ]; then
            cp --verbose /usr/lib/u-boot/rpi_4/u-boot.bin /boot/firmware/uboot_rpi_4.bin
        fi
        if [ -f /usr/lib/u-boot/rpi_arm64/u-boot.bin ]; then
            cp --verbose /usr/lib/u-boot/rpi_arm64/u-boot.bin /boot/firmware/uboot_rpi_arm64.bin
        fi
        if [ -f /usr/lib/u-boot/rpi_5/u-boot.bin ]; then
            cp --verbose /usr/lib/u-boot/rpi_5/u-boot.bin /boot/firmware/uboot_rpi_5.bin
        fi
        ;;
esac

# Create missing network-manager file
touch /etc/NetworkManager/conf.d/10-globally-managed-devices.conf

# Platform-specific post-installation configuration
case "$PLATFORM" in
    pi5)
        echo "Applying Raspberry Pi 5 specific configurations..."
        # Enable PCIe support for NVMe drives
        if [ -f /etc/modules ]; then
            echo "# Enable PCIe support for Pi 5" >> /etc/modules
            echo "pcie_brcmstb" >> /etc/modules
        fi
        
        # Create a boot message indicating Pi 5 support
        echo "Pop-OS for Raspberry Pi 5 - $(date)" > /etc/motd
        echo "This system is optimized for Raspberry Pi 5 hardware." >> /etc/motd
        echo "" >> /etc/motd
        ;;
    pi4)
        echo "Applying Raspberry Pi 4 specific configurations..."
        # Create a boot message indicating Pi 4 support
        echo "Pop-OS for Raspberry Pi 4 - $(date)" > /etc/motd
        echo "This system is optimized for Raspberry Pi 4 hardware." >> /etc/motd
        echo "" >> /etc/motd
        ;;
esac

# Set hostname based on platform
case "$PLATFORM" in
    pi5)
        echo "pop-os-pi5" > /etc/hostname
        sed -i 's/127.0.1.1\s*pop-os/127.0.1.1\tpop-os-pi5/' /etc/hosts
        ;;
    pi4)
        echo "pop-os-pi4" > /etc/hostname
        sed -i 's/127.0.1.1\s*pop-os/127.0.1.1\tpop-os-pi4/' /etc/hosts
        ;;
    *)
        echo "pop-os-raspi" > /etc/hostname
        sed -i 's/127.0.1.1\s*pop-os/127.0.1.1\tpop-os-raspi/' /etc/hosts
        ;;
esac

echo "Chroot configuration completed for $PLATFORM"
