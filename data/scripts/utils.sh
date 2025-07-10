#!/usr/bin/env bash

# Pop-OS Raspberry Pi Image Builder
# Common utility functions

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        log_error "This script should not be run as root"
        exit 1
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check required dependencies
check_dependencies() {
    local missing_deps=()
    
    local deps=(
        "debootstrap"
        "systemd-nspawn"
        "pixz"
        "parted"
        "mkfs.vfat"
        "mkfs.ext4"
        "rsync"
        "losetup"
        "mount"
        "umount"
    )
    
    for dep in "${deps[@]}"; do
        if ! command_exists "$dep"; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Run 'make deps' to install missing dependencies"
        return 1
    fi
    
    return 0
}

# Validate platform
validate_platform() {
    local platform="$1"
    
    case "$platform" in
        pi4|pi5)
            return 0
            ;;
        *)
            log_error "Invalid platform: $platform"
            log_info "Valid platforms: pi4, pi5"
            return 1
            ;;
    esac
}

# Get platform display name
get_platform_name() {
    local platform="$1"
    
    case "$platform" in
        pi4)
            echo "Raspberry Pi 4"
            ;;
        pi5)
            echo "Raspberry Pi 5"
            ;;
        *)
            echo "Unknown Platform"
            ;;
    esac
}

# Check available disk space
check_disk_space() {
    local path="$1"
    local required_gb="$2"
    
    # Get available space in GB
    local available_gb=$(df -BG "$path" | awk 'NR==2 {print $4}' | sed 's/G//')
    
    if [ "$available_gb" -lt "$required_gb" ]; then
        log_error "Insufficient disk space in $path"
        log_info "Required: ${required_gb}GB, Available: ${available_gb}GB"
        return 1
    fi
    
    return 0
}

# Clean up function for interrupted builds
cleanup_build() {
    local build_dir="$1"
    
    if [ -n "$build_dir" ] && [ -d "$build_dir" ]; then
        log_info "Cleaning up build directory: $build_dir"
        
        # Unmount any mounted filesystems
        local mount_dir="$build_dir/mount"
        if [ -d "$mount_dir" ]; then
            log_info "Unmounting filesystems in $mount_dir"
            umount "$mount_dir/boot/firmware" 2>/dev/null || true
            umount "$mount_dir" 2>/dev/null || true
        fi
        
        # Detach any loop devices
        local image_file="$build_dir/raspi.img"
        if [ -f "$image_file" ]; then
            log_info "Detaching loop devices for $image_file"
            losetup --associated "$image_file" 2>/dev/null | cut -d ':' -f1 | while read lodev; do
                if [ -n "$lodev" ]; then
                    losetup --detach "$lodev" 2>/dev/null || true
                fi
            done
        fi
        
        # Remove partial files
        rm -f "$build_dir"/*.partial 2>/dev/null || true
    fi
}

# Progress indicator
show_progress() {
    local pid=$1
    local message="$2"
    
    local spin='-\|/'
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r${BLUE}[%c]${NC} %s" "${spin:$i:1}" "$message"
        sleep 0.1
    done
    printf "\r${GREEN}[✓]${NC} %s\n" "$message"
}

# Format bytes to human readable
format_bytes() {
    local bytes=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    
    while [ $bytes -ge 1024 ] && [ $unit -lt $((${#units[@]} - 1)) ]; do
        bytes=$((bytes / 1024))
        unit=$((unit + 1))
    done
    
    echo "${bytes}${units[$unit]}"
}

# Create build summary
create_build_summary() {
    local platform="$1"
    local image_file="$2"
    local build_time="$3"
    
    log_success "Build completed successfully!"
    echo "═══════════════════════════════════════════════════════════════"
    echo "Platform: $(get_platform_name "$platform")"
    echo "Image: $image_file"
    if [ -f "$image_file" ]; then
        echo "Size: $(du -h "$image_file" | cut -f1)"
    fi
    echo "Build time: $build_time"
    echo "═══════════════════════════════════════════════════════════════"
    echo "To flash the image:"
    echo "1. Insert SD card/USB drive"
    echo "2. Run: sudo dd if=$image_file of=/dev/sdX bs=4M status=progress"
    echo "3. Or use Raspberry Pi Imager"
    echo ""
    echo "Default credentials:"
    echo "Username: pop-os"
    echo "Password: (set during first boot)"
    echo "═══════════════════════════════════════════════════════════════"
}

# Validate build environment
validate_build_environment() {
    local platform="$1"
    local data_dir="$2"
    
    log_info "Validating build environment..."
    
    # Check dependencies
    if ! check_dependencies; then
        return 1
    fi
    
    # Check platform
    if ! validate_platform "$platform"; then
        return 1
    fi
    
    # Check data directories
    local platform_dir="$data_dir/$platform"
    if [ ! -d "$platform_dir" ]; then
        log_error "Platform directory not found: $platform_dir"
        return 1
    fi
    
    if [ ! -f "$platform_dir/boot/firmware/config.txt" ]; then
        log_error "Platform config.txt not found: $platform_dir/boot/firmware/config.txt"
        return 1
    fi
    
    local common_dir="$data_dir/common"
    if [ ! -d "$common_dir" ]; then
        log_error "Common directory not found: $common_dir"
        return 1
    fi
    
    # Check disk space (require 16GB minimum)
    if ! check_disk_space "." 16; then
        return 1
    fi
    
    log_success "Build environment validation passed"
    return 0
} 