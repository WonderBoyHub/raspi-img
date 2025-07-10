# Pop-OS Raspberry Pi Image Builder
# Supports both Raspberry Pi 4 and Raspberry Pi 5

# Build configuration
ARCH=arm64
UBUNTU_CODE?=noble
UBUNTU_MIRROR?=http://ports.ubuntu.com/ubuntu-ports
TARGET_PLATFORM?=pi4

# Platform-specific configurations
ifeq ($(TARGET_PLATFORM),pi5)
BUILD_SUFFIX=pi5
PLATFORM_DIR=pi5
else
BUILD_SUFFIX=pi4
PLATFORM_DIR=pi4
endif

# Build directories
BUILD_BASE=build/$(UBUNTU_CODE)
BUILD_DIR=$(BUILD_BASE)/$(BUILD_SUFFIX)
COMMON_DIR=data/common
PLATFORM_DATA_DIR=data/$(PLATFORM_DIR)

# Template substitution
SED=\
	s|UBUNTU_CODE|$(UBUNTU_CODE)|g; \
	s|UBUNTU_MIRROR|$(UBUNTU_MIRROR)|g; \
	s|TARGET_PLATFORM|$(TARGET_PLATFORM)|g

# Default target
all: pi4 pi5

# Platform-specific targets
pi4:
	$(MAKE) TARGET_PLATFORM=pi4 $(BUILD_BASE)/pi4/raspi.img.xz

pi5:
	$(MAKE) TARGET_PLATFORM=pi5 $(BUILD_BASE)/pi5/raspi.img.xz

# Build single platform
build: $(BUILD_DIR)/raspi.img.xz

# Clean targets
clean:
	@echo "Cleaning build artifacts..."
	# Remove image files
	sudo rm -f "$(BUILD_DIR)/raspi.img" "$(BUILD_DIR)/raspi.img.partial"
	
	# Remove compressed files
	rm -f "$(BUILD_DIR)/raspi.img.xz" "$(BUILD_DIR)/raspi.img.xz.partial"
	
	# Handle cleanup failures gracefully
	if [ $$? -ne 0 ] && [ -d "$(BUILD_DIR)" ]; then \
		echo "Warning: Some files could not be removed, moving to temp directory"; \
		mv "$(BUILD_DIR)" "/tmp/$(BUILD_SUFFIX)-$(shell date +%s)-to-be-deleted" 2>/dev/null || true; \
	fi

clean-all:
	@echo "Cleaning all build artifacts..."
	sudo rm -rf --one-file-system build/
	sudo rm -rf --one-file-system "$(COMMON_DIR)/etc/apt/sources.list.d"

distclean: clean
	@echo "Deep cleaning debootstrap directories..."
	sudo rm -rf --one-file-system "$(BUILD_DIR)/debootstrap" "$(BUILD_DIR)/debootstrap.partial"

distclean-all:
	@echo "Deep cleaning all debootstrap directories..."
	sudo rm -rf --one-file-system build/*/debootstrap build/*/debootstrap.partial

# Dependencies installation
deps:
	@echo "Installing build dependencies..."
	@if [ ! -f /usr/sbin/debootstrap ]; then \
		echo "Installing debootstrap..."; \
		sudo apt-get update; \
		sudo apt-get install --yes debootstrap; \
	fi
	@if [ ! -f /usr/bin/systemd-nspawn ]; then \
		echo "Installing systemd-container..."; \
		sudo apt-get install --yes systemd-container; \
	fi
	@if [ ! -f /usr/bin/pixz ]; then \
		echo "Installing pixz..."; \
		sudo apt-get install --yes pixz; \
	fi
	@echo "Checking for additional dependencies..."
	@sudo apt-get install --yes parted dosfstools e2fsprogs rsync wget git

# System info
info:
	@echo "Build Configuration:"
	@echo "  Architecture: $(ARCH)"
	@echo "  Ubuntu Code: $(UBUNTU_CODE)"
	@echo "  Ubuntu Mirror: $(UBUNTU_MIRROR)"
	@echo "  Target Platform: $(TARGET_PLATFORM)"
	@echo "  Build Directory: $(BUILD_DIR)"
	@echo "  Platform Data: $(PLATFORM_DATA_DIR)"

# Validation
validate:
	@echo "Validating build environment..."
	@if [ ! -d "$(PLATFORM_DATA_DIR)" ]; then \
		echo "Error: Platform data directory not found: $(PLATFORM_DATA_DIR)"; \
		exit 1; \
	fi
	@if [ ! -f "$(PLATFORM_DATA_DIR)/boot/firmware/config.txt" ]; then \
		echo "Error: Platform config.txt not found"; \
		exit 1; \
	fi
	@echo "Environment validation passed"

# Create debootstrap environment
$(BUILD_DIR)/debootstrap: validate
	@echo "Creating debootstrap environment for $(TARGET_PLATFORM)..."
	mkdir -p "$(BUILD_DIR)"
	
	# Remove old debootstrap
	sudo rm -rf --one-file-system "$@" "$@.partial"
	
	# Install using debootstrap
	if ! sudo debootstrap \
		"--arch=$(ARCH)" \
		"--foreign" \
		"$(UBUNTU_CODE)" \
		"$@.partial" \
		"$(UBUNTU_MIRROR)"; \
	then \
		echo "Debootstrap failed. Log content:"; \
		cat "$@.partial/debootstrap/debootstrap.log" 2>/dev/null || echo "No log file found"; \
		exit 1; \
	fi
	
	# Copy QEMU static binary for ARM64 emulation
	if [ "$(ARCH)" = "arm64" ]; then \
		echo "Copying QEMU static binary for ARM64 emulation..."; \
		sudo cp /usr/bin/qemu-aarch64-static "$@.partial/usr/bin/"; \
	fi
	
	# Complete debootstrap second stage
	if ! sudo chroot "$@.partial" /debootstrap/debootstrap --second-stage; \
	then \
		echo "Debootstrap second stage failed. Log content:"; \
		cat "$@.partial/debootstrap/debootstrap.log" 2>/dev/null || echo "No log file found"; \
		exit 1; \
	fi
	
	# Mark as complete
	sudo touch "$@.partial"
	sudo mv "$@.partial" "$@"
	@echo "Debootstrap completed successfully"

# Create bootable image
$(BUILD_DIR)/raspi.img: $(BUILD_DIR)/debootstrap
	@echo "Creating $(TARGET_PLATFORM) bootable image..."
	
	# Generate platform-specific templates
	rm -rf "$(COMMON_DIR)/etc/apt/sources.list.d"
	mkdir -p "$(COMMON_DIR)/etc/apt/sources.list.d"
	
	# Create APT sources from templates
	sed "$(SED)" "$(COMMON_DIR)/template/pop-os-release.sources" > "$(COMMON_DIR)/etc/apt/sources.list.d/pop-os-release.sources"
	sed "$(SED)" "$(COMMON_DIR)/template/system.sources" > "$(COMMON_DIR)/etc/apt/sources.list.d/system.sources"
	
	# Create image using platform-specific script
	sudo data/scripts/image.sh \
		"$@.partial" \
		"$(BUILD_DIR)/mount" \
		"$<" \
		"$(UBUNTU_CODE)" \
		"$(UBUNTU_MIRROR)" \
		"$(TARGET_PLATFORM)"
	
	# Mark as complete
	sudo touch "$@.partial"
	sudo mv "$@.partial" "$@"
	@echo "Image creation completed"

# Create compressed image
$(BUILD_DIR)/raspi.img.xz: $(BUILD_DIR)/raspi.img
	@echo "Compressing $(TARGET_PLATFORM) image..."
	
	# Create compressed file with progress
	pixz -9 -t "$<" "$@.partial"
	
	# Mark as complete
	sudo touch "$@.partial"
	sudo mv "$@.partial" "$@"
	
	@echo "Compression completed: $@"
	@echo "Image size: $(shell du -h "$@" | cut -f1)"

# Development and testing targets
test: validate
	@echo "Running basic validation tests..."
	@if [ ! -f "$(BUILD_DIR)/raspi.img.xz" ]; then \
		echo "Error: No image file found to test"; \
		exit 1; \
	fi
	@echo "Image file exists and is readable"
	@echo "Tests passed"

# Help target
help:
	@echo "Pop-OS Raspberry Pi Image Builder"
	@echo ""
	@echo "Usage:"
	@echo "  make [target] [variables]"
	@echo ""
	@echo "Targets:"
	@echo "  all          - Build images for both Pi 4 and Pi 5"
	@echo "  pi4          - Build Raspberry Pi 4 image"
	@echo "  pi5          - Build Raspberry Pi 5 image"
	@echo "  build        - Build for current TARGET_PLATFORM"
	@echo "  clean        - Clean current platform build files"
	@echo "  clean-all    - Clean all build files"
	@echo "  distclean    - Deep clean current platform"
	@echo "  distclean-all- Deep clean all platforms"
	@echo "  deps         - Install build dependencies"
	@echo "  info         - Show build configuration"
	@echo "  validate     - Validate build environment"
	@echo "  test         - Run basic validation tests"
	@echo "  help         - Show this help message"
	@echo ""
	@echo "Variables:"
	@echo "  UBUNTU_CODE     - Ubuntu release (default: noble)"
	@echo "  UBUNTU_MIRROR   - Ubuntu mirror URL"
	@echo "  TARGET_PLATFORM - Target platform: pi4 or pi5 (default: pi4)"
	@echo "  ARCH            - Architecture (default: arm64)"
	@echo ""
	@echo "Examples:"
	@echo "  make pi5                              - Build Pi 5 image"
	@echo "  make pi4 UBUNTU_CODE=jammy           - Build Pi 4 with Ubuntu 22.04"
	@echo "  make all                             - Build both platforms"
	@echo "  TARGET_PLATFORM=pi5 make build      - Build Pi 5 using environment var"

# Phony targets
.PHONY: all pi4 pi5 build clean clean-all distclean distclean-all deps info validate test help
