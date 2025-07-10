# Troubleshooting Guide

This guide covers common issues you might encounter while building or using Pop-OS Raspberry Pi images.

## 🔧 Build Issues

### Permission Errors

**Problem**: Build fails with permission denied errors
```bash
sudo: required for debootstrap
Permission denied: /dev/loop0
```

**Solution**:
```bash
# Make sure you're not running as root
whoami  # Should not be root

# Clean and retry
make clean
make deps
make pi4  # or pi5
```

### Insufficient Disk Space

**Problem**: Build fails with "No space left on device"
```bash
fallocate: cannot allocate memory: No space left on device
```

**Solution**:
```bash
# Check available space (need at least 16GB)
df -h .

# Clean old builds
make clean-all

# Free up space and retry
make pi4
```

### Network Issues

**Problem**: Build fails during package download
```bash
E: Failed to fetch http://ports.ubuntu.com/ubuntu-ports/...
```

**Solution**:
```bash
# Check internet connection
ping -c 4 google.com

# Try different mirror
UBUNTU_MIRROR=http://archive.ubuntu.com/ubuntu make pi4

# Or use local mirror
UBUNTU_MIRROR=http://us.archive.ubuntu.com/ubuntu make pi4
```

### Debootstrap Failures

**Problem**: Debootstrap fails with various errors
```bash
I: Retrieving Release
E: Failed getting release file
```

**Solution**:
```bash
# Check debootstrap log
cat build/noble/pi4/debootstrap.partial/debootstrap/debootstrap.log

# Clean and retry with different mirror
make distclean
UBUNTU_MIRROR=http://archive.ubuntu.com/ubuntu make pi4

# If still failing, try older Ubuntu version
UBUNTU_CODE=jammy make pi4
```

### Loop Device Issues

**Problem**: Cannot create or detach loop devices
```bash
losetup: /dev/loop0: device is busy
```

**Solution**:
```bash
# Check active loop devices
losetup -l

# Force cleanup
sudo make clean

# If still stuck, reboot and try again
sudo reboot
```

## 🎯 Platform-Specific Issues

### Raspberry Pi 4 Issues

**Problem**: Pi 4 won't boot from USB
```bash
Rainbow screen, no boot
```

**Solution**:
1. Update Pi 4 bootloader first:
   ```bash
   # Boot from SD card with Raspberry Pi OS
   sudo rpi-eeprom-update -a
   sudo reboot
   ```

2. Enable USB boot:
   ```bash
   sudo raspi-config
   # Advanced Options → Boot Order → USB Boot
   ```

### Raspberry Pi 5 Issues

**Problem**: Pi 5 image won't boot
```bash
Kernel panic or black screen
```

**Solution**:
1. Check power supply (5V/5A recommended for Pi 5)
2. Verify SD card/USB drive integrity
3. Try different SD card
4. Check for firmware updates

**Problem**: NVMe drive not detected
```bash
No NVMe devices found
```

**Solution**:
1. Check NVMe compatibility (not all drives work)
2. Update Pi 5 bootloader:
   ```bash
   sudo rpi-eeprom-update -a
   ```
3. Enable PCIe in config.txt:
   ```txt
   dtparam=pciex1
   ```

## 💻 Runtime Issues

### First Boot Problems

**Problem**: System hangs during first boot
```bash
Stuck at "Starting kernel..."
```

**Solution**:
1. Check power supply (minimum 5V/3A)
2. Try different SD card
3. Enable SSH and check logs:
   ```bash
   # Add empty 'ssh' file to boot partition
   touch /boot/firmware/ssh
   ```

### Network Issues

**Problem**: No network connectivity
```bash
No ethernet or WiFi
```

**Solution**:
1. Check cable connections
2. For WiFi, configure during first boot
3. Check network manager:
   ```bash
   sudo systemctl status NetworkManager
   sudo systemctl restart NetworkManager
   ```

### Graphics Issues

**Problem**: No display output or poor performance
```bash
Black screen or artifacts
```

**Solution**:
1. Check HDMI cable and monitor
2. Try different HDMI port
3. Adjust config.txt:
   ```txt
   hdmi_force_hotplug=1
   hdmi_drive=2
   ```

### Audio Issues

**Problem**: No audio output
```bash
No sound from HDMI or 3.5mm
```

**Solution**:
1. Check audio settings in desktop
2. Force HDMI audio:
   ```txt
   hdmi_drive=2
   ```
3. Test audio:
   ```bash
   speaker-test -t wav
   ```

## 🔍 Debugging Tools

### Build Debugging

```bash
# Verbose build output
make pi4 V=1

# Check build configuration
make info

# Validate environment
make validate TARGET_PLATFORM=pi4

# Check dependencies
make deps
```

### Runtime Debugging

```bash
# Check system logs
sudo journalctl -b

# Check hardware detection
lsusb
lspci
lsblk

# Check kernel messages
dmesg | tail -20

# Check network
ip addr show
ping -c 4 google.com
```

### Image Debugging

```bash
# Mount image for inspection
sudo losetup -P /dev/loop0 image.img
sudo mkdir -p /mnt/root /mnt/boot
sudo mount /dev/loop0p2 /mnt/root
sudo mount /dev/loop0p1 /mnt/boot

# Check image contents
ls -la /mnt/root
ls -la /mnt/boot

# Cleanup
sudo umount /mnt/root /mnt/boot
sudo losetup -d /dev/loop0
```

## 📋 Common Error Messages

### "No space left on device"
- **Cause**: Insufficient disk space
- **Solution**: Free up space, need 16GB minimum

### "Permission denied"
- **Cause**: Insufficient permissions
- **Solution**: Don't run as root, use sudo only when needed

### "Package not found"
- **Cause**: Package repository issues
- **Solution**: Update package cache, try different mirror

### "Loop device busy"
- **Cause**: Loop device still in use
- **Solution**: Clean up loop devices, reboot if necessary

### "Kernel panic"
- **Cause**: Hardware incompatibility or corrupt image
- **Solution**: Check hardware, rebuild image

## 🛠️ Advanced Troubleshooting

### Enable Debug Mode

Add to config.txt:
```txt
# Enable debug output
enable_uart=1
dtdebug=1
```

### Serial Console Access

1. Enable UART in config.txt:
   ```txt
   enable_uart=1
   ```

2. Connect serial adapter to GPIO pins
3. Use screen or minicom:
   ```bash
   screen /dev/ttyUSB0 115200
   ```

### Recovery Mode

If system won't boot:
1. Mount boot partition on another system
2. Add to cmdline.txt:
   ```txt
   systemd.unit=rescue.target
   ```
3. Boot into recovery mode

### Image Repair

For corrupted images:
```bash
# Check filesystem
sudo fsck /dev/loop0p2

# Repair if needed
sudo fsck -y /dev/loop0p2
```

## 📞 Getting Help

### Before Asking for Help

1. Check this troubleshooting guide
2. Search existing GitHub issues
3. Try the solutions provided
4. Collect relevant information:
   - Platform (Pi 4 or Pi 5)
   - Host OS and version
   - Error messages
   - Build configuration
   - Steps to reproduce

### How to Report Issues

1. Use the GitHub issue template
2. Include full error messages
3. Provide build logs
4. Mention what you've already tried

### Community Resources

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and help
- **Ubuntu Forums**: Ubuntu-specific issues
- **Raspberry Pi Forums**: Hardware-specific issues

---

**Still having issues?** Don't hesitate to open a GitHub issue with detailed information about your problem! 