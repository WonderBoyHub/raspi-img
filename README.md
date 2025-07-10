# Pop-OS Raspberry Pi Image Builder

An open source project for building Pop-OS images for Raspberry Pi 4 and Raspberry Pi 5, based on Ubuntu and Pop-OS components.

## 🚀 Features

- **Multi-Platform Support**: Build images for both Raspberry Pi 4 and Raspberry Pi 5
- **Pop-OS Desktop**: Full Pop-OS desktop environment optimized for ARM64
- **Automated Build**: Simple Makefile-based build system
- **Customizable**: Easy to modify and extend for your needs
- **Open Source**: GPL-3.0 licensed, community-driven development

## 📋 Prerequisites

### System Requirements
- Ubuntu 20.04+ or Debian 11+ (host system)
- At least 16GB of free disk space
- 4GB+ RAM recommended
- Root/sudo access

### Dependencies
Install required packages:
```bash
sudo apt update
sudo apt install -y \
    debootstrap \
    systemd-container \
    pixz \
    parted \
    dosfstools \
    e2fsprogs \
    rsync \
    wget \
    git
```

Or use the automatic dependency installer:
```bash
make deps
```

## 🛠️ Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/pop-os-raspi-builder.git
cd pop-os-raspi-builder
```

### 2. Build for Raspberry Pi 4
```bash
make pi4
```

### 3. Build for Raspberry Pi 5
```bash
make pi5
```

### 4. Build for Both Platforms
```bash
make all
```

## 📁 Project Structure

```
pop-os-raspi-builder/
├── README.md                 # This file
├── LICENSE                   # GPL-3.0 license
├── Makefile                  # Build system
├── .github/                  # GitHub Actions workflows
│   └── workflows/
│       └── build.yml         # Automated CI/CD
├── data/                     # Build data and configurations
│   ├── pi4/                  # Raspberry Pi 4 specific files
│   │   ├── boot/firmware/    # Pi 4 firmware and config
│   │   └── etc/              # Pi 4 system configuration
│   ├── pi5/                  # Raspberry Pi 5 specific files
│   │   ├── boot/firmware/    # Pi 5 firmware and config
│   │   └── etc/              # Pi 5 system configuration
│   ├── common/               # Shared configurations
│   │   ├── etc/              # Common system files
│   │   └── template/         # APT source templates
│   ├── scripts/              # Build scripts
│   │   ├── image.sh          # Image creation script
│   │   ├── chroot.sh         # Package installation script
│   │   └── utils.sh          # Utility functions
│   └── overlays/             # Custom overlays and modifications
├── build/                    # Build output (auto-generated)
│   ├── pi4/                  # Pi 4 build artifacts
│   └── pi5/                  # Pi 5 build artifacts
├── docs/                     # Documentation
│   ├── BUILDING.md           # Detailed build instructions
│   ├── CONTRIBUTING.md       # Contribution guidelines
│   ├── TROUBLESHOOTING.md    # Common issues and solutions
│   └── CUSTOMIZATION.md      # How to customize builds
└── tests/                    # Test scripts and validation
    ├── validate-image.sh     # Image validation tests
    └── qemu-test.sh          # QEMU testing (where applicable)
```

## 🔧 Configuration

### Build Variables
You can customize the build by setting environment variables:

```bash
# Ubuntu release (default: noble)
export UBUNTU_CODE=noble

# Ubuntu mirror (default: ports.ubuntu.com)
export UBUNTU_MIRROR=http://ports.ubuntu.com/ubuntu-ports

# Architecture (default: arm64)
export ARCH=arm64

# Target platform (pi4 or pi5)
export TARGET_PLATFORM=pi5
```

### Example Custom Build
```bash
UBUNTU_CODE=jammy TARGET_PLATFORM=pi4 make build
```

## 🎯 Platform-Specific Features

### Raspberry Pi 4
- ✅ Hardware video acceleration
- ✅ GPIO support
- ✅ I2C/SPI interfaces
- ✅ Camera module support
- ✅ USB boot support
- ✅ 4K@60Hz HDMI output

### Raspberry Pi 5
- ✅ Enhanced performance
- ✅ PCIe support
- ✅ Dual 4K@60Hz displays
- ✅ Improved GPIO performance
- ✅ Better power management
- ✅ NVMe SSD support

## 🐛 Troubleshooting

### Common Issues

1. **Build fails with permission errors**
   ```bash
   sudo make clean
   make deps
   ```

2. **Insufficient disk space**
   - Ensure at least 16GB free space
   - Use `make clean` to remove old builds

3. **Network issues during build**
   - Check internet connection
   - Try different Ubuntu mirror

4. **Image won't boot**
   - Verify SD card/USB drive integrity
   - Check power supply (5V/3A minimum)
   - Enable SSH for debugging

For more detailed troubleshooting, see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](docs/CONTRIBUTING.md) for guidelines.

### Quick Contribution Steps
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the GPL-3.0 License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Pop-OS](https://pop.system76.com/) by System76
- [Ubuntu](https://ubuntu.com/) by Canonical
- [Raspberry Pi Foundation](https://www.raspberrypi.org/)
- Original [pop-os/raspi-img](https://github.com/pop-os/raspi-img) project

## 🔗 Links

- [Pop-OS Official Site](https://pop.system76.com/)
- [Raspberry Pi Documentation](https://www.raspberrypi.org/documentation/)
- [Ubuntu ARM](https://ubuntu.com/download/raspberry-pi)
- [Issue Tracker](https://github.com/yourusername/pop-os-raspi-builder/issues)
- [Discussions](https://github.com/yourusername/pop-os-raspi-builder/discussions)

## 📊 Build Status

[![Build Status](https://github.com/yourusername/pop-os-raspi-builder/workflows/Build/badge.svg)](https://github.com/yourusername/pop-os-raspi-builder/actions)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform](https://img.shields.io/badge/Platform-Raspberry%20Pi%204%2F5-red.svg)](https://www.raspberrypi.org/)

---

**Note**: This project is a community effort and is not officially affiliated with Pop-OS, System76, or the Raspberry Pi Foundation.
