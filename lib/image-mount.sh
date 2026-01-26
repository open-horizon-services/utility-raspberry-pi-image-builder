#!/bin/bash

# Image Mount Utility
# Cross-platform utility for mounting and unmounting disk images
# Supports Linux (losetup) and macOS (hdiutil) platforms

set -euo pipefail

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DETECTED_PLATFORM=""
MOUNTED_DEVICES=()
LOG_FILE=""

# Initialize logging if not already set
init_logging() {
    if [[ -z "${LOG_FILE:-}" ]]; then
        LOG_FILE="${SCRIPT_DIR}/image-mount.log"
        echo "=== Image Mount Utility Started at $(date) ===" > "$LOG_FILE"
    fi
}

# Logging functions
log_info() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] INFO: $message" | tee -a "${LOG_FILE:-/dev/stdout}"
}

log_warn() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] WARN: $message" | tee -a "${LOG_FILE:-/dev/stdout}" >&2
}

log_error() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] ERROR: $message" | tee -a "${LOG_FILE:-/dev/stdout}" >&2
}

log_debug() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    if [[ "${DEBUG:-}" == "1" ]]; then
        echo "[$timestamp] DEBUG: $message" | tee -a "${LOG_FILE:-/dev/stdout}"
    else
        echo "[$timestamp] DEBUG: $message" >> "${LOG_FILE:-/dev/null}"
    fi
}

# Platform detection
detect_platform() {
    log_debug "Detecting platform..."
    
    local uname_output=$(uname -s)
    case "$uname_output" in
        Linux*)
            DETECTED_PLATFORM="linux"
            ;;
        Darwin*)
            DETECTED_PLATFORM="macos"
            ;;
        *)
            log_error "Unsupported platform: $uname_output"
            log_error "This utility only supports Linux and macOS"
            exit 1
            ;;
    esac
    
    log_debug "Detected platform: $DETECTED_PLATFORM"
}

# Mount image filesystem with platform-specific implementation
# Usage: mount_image <image_path> <mount_point>
# Returns: 0 on success, 1 on failure, outputs loop device name
mount_image() {
    local image_path="$1"
    local mount_point="$2"
    local loop_device=""
    local retry_count=0
    local max_retries=3
    
    log_info "Mounting image: $image_path"
    log_debug "Mount point: $mount_point"
    
    # Validate inputs
    if [[ -z "$image_path" || -z "$mount_point" ]]; then
        log_error "mount_image: Missing required parameters"
        return 1
    fi
    
    if [[ ! -f "$image_path" ]]; then
        log_error "mount_image: Image file does not exist: $image_path"
        return 1
    fi
    
    # Create mount point if it doesn't exist
    if [[ ! -d "$mount_point" ]]; then
        log_debug "Creating mount point: $mount_point"
        mkdir -p "$mount_point" || {
            log_error "mount_image: Failed to create mount point: $mount_point"
            return 1
        }
    fi
    
    # Platform-specific mounting with retry logic
    while [[ $retry_count -lt $max_retries ]]; do
        case "$DETECTED_PLATFORM" in
            linux)
                loop_device=$(mount_image_linux "$image_path" "$mount_point")
                local mount_result=$?
                ;;
            macos)
                loop_device=$(mount_image_macos "$image_path" "$mount_point")
                local mount_result=$?
                ;;
            *)
                log_error "mount_image: Unsupported platform: $DETECTED_PLATFORM"
                return 1
                ;;
        esac
        
        if [[ $mount_result -eq 0 && -n "$loop_device" ]]; then
            log_info "Successfully mounted image on device: $loop_device"
            MOUNTED_DEVICES+=("$loop_device")
            echo "$loop_device"
            return 0
        fi
        
        retry_count=$((retry_count + 1))
        if [[ $retry_count -lt $max_retries ]]; then
            log_warn "Mount attempt $retry_count failed, retrying in 2 seconds..."
            sleep 2
        fi
    done
    
    log_error "mount_image: Failed to mount after $max_retries attempts"
    return 1
}

mount_image_linux() {
    local image_path="$1"
    local mount_point="$2"
    local loop_device=""
    
    log_debug "Using Linux losetup for mounting"
    
    # Set up loop device with partition probing
    loop_device=$(sudo losetup --find --partscan --show "$image_path" 2>/dev/null)
    if [[ $? -ne 0 || -z "$loop_device" ]]; then
        log_error "mount_image_linux: Failed to create loop device for $image_path"
        return 1
    fi
    
    log_debug "Created loop device: $loop_device"
    
    # Wait for partition devices to appear
    sleep 1
    
    # Find the root partition (usually the second partition)
    local root_partition="${loop_device}p2"
    if [[ ! -b "$root_partition" ]]; then
        # Try alternative naming scheme
        root_partition="${loop_device}2"
        if [[ ! -b "$root_partition" ]]; then
            log_error "mount_image_linux: Root partition not found for $loop_device"
            sudo losetup -d "$loop_device" 2>/dev/null || true
            return 1
        fi
    fi
    
    log_debug "Found root partition: $root_partition"
    
    # Mount the root partition
    if ! sudo mount "$root_partition" "$mount_point" 2>/dev/null; then
        log_error "mount_image_linux: Failed to mount $root_partition to $mount_point"
        sudo losetup -d "$loop_device" 2>/dev/null || true
        return 1
    fi
    
    # Mount the boot partition if it exists
    local boot_partition="${loop_device}p1"
    if [[ ! -b "$boot_partition" ]]; then
        boot_partition="${loop_device}1"
    fi
    
    if [[ -b "$boot_partition" ]]; then
        local boot_mount="${mount_point}/boot"
        if [[ -d "$boot_mount" ]]; then
            log_debug "Mounting boot partition: $boot_partition to $boot_mount"
            sudo mount "$boot_partition" "$boot_mount" 2>/dev/null || {
                log_warn "mount_image_linux: Failed to mount boot partition (non-critical)"
            }
        fi
    fi
    
    echo "$loop_device"
    return 0
}

mount_image_macos() {
    local image_path="$1"
    local mount_point="$2"
    local disk_device=""
    
    log_debug "Using macOS hdiutil for mounting"
    
    # Attach the disk image
    local attach_output
    attach_output=$(hdiutil attach "$image_path" -nobrowse -mountpoint "$mount_point" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        log_error "mount_image_macos: Failed to attach disk image: $image_path"
        return 1
    fi
    
    # Extract the disk device from hdiutil output
    disk_device=$(echo "$attach_output" | grep -E '^/dev/disk[0-9]+' | head -1 | awk '{print $1}')
    if [[ -z "$disk_device" ]]; then
        log_error "mount_image_macos: Could not determine disk device from hdiutil output"
        hdiutil detach "$mount_point" 2>/dev/null || true
        return 1
    fi
    
    log_debug "Attached disk device: $disk_device"
    
    # Verify the mount was successful
    if [[ ! -d "$mount_point" ]] || ! mountpoint -q "$mount_point" 2>/dev/null; then
        log_error "mount_image_macos: Mount point verification failed"
        hdiutil detach "$disk_device" 2>/dev/null || true
        return 1
    fi
    
    echo "$disk_device"
    return 0
}

# Unmount image filesystem with platform-specific implementation
# Usage: unmount_image <device> <mount_point>
# Returns: 0 on success, 1 on failure
unmount_image() {
    local device="$1"
    local mount_point="$2"
    local retry_count=0
    local max_retries=3
    
    log_info "Unmounting device: $device"
    log_debug "Mount point: $mount_point"
    
    # Validate inputs
    if [[ -z "$device" ]]; then
        log_error "unmount_image: Device parameter is required"
        return 1
    fi
    
    # Platform-specific unmounting with retry logic
    while [[ $retry_count -lt $max_retries ]]; do
        case "$DETECTED_PLATFORM" in
            linux)
                if unmount_image_linux "$device" "$mount_point"; then
                    log_info "Successfully unmounted device: $device"
                    # Remove from mounted devices array
                    local new_array=()
                    for mounted_device in "${MOUNTED_DEVICES[@]}"; do
                        if [[ "$mounted_device" != "$device" ]]; then
                            new_array+=("$mounted_device")
                        fi
                    done
                    MOUNTED_DEVICES=("${new_array[@]}")
                    return 0
                fi
                ;;
            macos)
                if unmount_image_macos "$device" "$mount_point"; then
                    log_info "Successfully unmounted device: $device"
                    # Remove from mounted devices array
                    local new_array=()
                    for mounted_device in "${MOUNTED_DEVICES[@]}"; do
                        if [[ "$mounted_device" != "$device" ]]; then
                            new_array+=("$mounted_device")
                        fi
                    done
                    MOUNTED_DEVICES=("${new_array[@]}")
                    return 0
                fi
                ;;
            *)
                log_error "unmount_image: Unsupported platform: $DETECTED_PLATFORM"
                return 1
                ;;
        esac
        
        retry_count=$((retry_count + 1))
        if [[ $retry_count -lt $max_retries ]]; then
            log_warn "Unmount attempt $retry_count failed, retrying in 2 seconds..."
            sleep 2
        fi
    done
    
    log_error "unmount_image: Failed to unmount after $max_retries attempts"
    return 1
}

unmount_image_linux() {
    local loop_device="$1"
    local mount_point="$2"
    
    log_debug "Using Linux umount and losetup for unmounting"
    
    # Unmount boot partition if mounted
    local boot_mount="${mount_point}/boot"
    if mountpoint -q "$boot_mount" 2>/dev/null; then
        log_debug "Unmounting boot partition: $boot_mount"
        sudo umount "$boot_mount" 2>/dev/null || {
            log_warn "unmount_image_linux: Failed to unmount boot partition (non-critical)"
        }
    fi
    
    # Unmount root partition
    if mountpoint -q "$mount_point" 2>/dev/null; then
        log_debug "Unmounting root partition: $mount_point"
        if ! sudo umount "$mount_point" 2>/dev/null; then
            log_error "unmount_image_linux: Failed to unmount $mount_point"
            return 1
        fi
    fi
    
    # Detach loop device
    if [[ -b "$loop_device" ]]; then
        log_debug "Detaching loop device: $loop_device"
        if ! sudo losetup -d "$loop_device" 2>/dev/null; then
            log_error "unmount_image_linux: Failed to detach loop device $loop_device"
            return 1
        fi
    fi
    
    return 0
}

unmount_image_macos() {
    local disk_device="$1"
    local mount_point="$2"
    
    log_debug "Using macOS hdiutil for unmounting"
    
    # Try to detach using the mount point first
    if [[ -n "$mount_point" ]] && mountpoint -q "$mount_point" 2>/dev/null; then
        log_debug "Detaching using mount point: $mount_point"
        if hdiutil detach "$mount_point" -force 2>/dev/null; then
            return 0
        fi
    fi
    
    # Try to detach using the disk device
    if [[ -n "$disk_device" ]]; then
        log_debug "Detaching using disk device: $disk_device"
        if hdiutil detach "$disk_device" -force 2>/dev/null; then
            return 0
        fi
    fi
    
    log_error "unmount_image_macos: Failed to detach disk image"
    return 1
}

# List mounted images
list_mounted_images() {
    log_info "Currently mounted images:"
    
    if [[ ${#MOUNTED_DEVICES[@]} -eq 0 ]]; then
        log_info "No images currently mounted by this utility"
        return 0
    fi
    
    for device in "${MOUNTED_DEVICES[@]}"; do
        if [[ -n "$device" ]]; then
            local mount_point
            case "$DETECTED_PLATFORM" in
                linux)
                    mount_point=$(findmnt -rn -o TARGET "$device" 2>/dev/null || echo "unknown")
                    ;;
                macos)
                    mount_point=$(mount | grep "$device" | head -1 | awk '{print $3}' || echo "unknown")
                    ;;
            esac
            echo "  - $device mounted at $mount_point"
        fi
    done
}

# Cleanup function
cleanup_mounts() {
    if [[ ${#MOUNTED_DEVICES[@]} -gt 0 ]]; then
        log_info "Cleaning up mounted devices..."
        for device in "${MOUNTED_DEVICES[@]}"; do
            if [[ -n "$device" ]]; then
                log_info "Unmounting device: $device"
                unmount_image "$device" "/tmp/mount_point_$$" || true
            fi
        done
    fi
}

# CLI interface
show_usage() {
    cat << EOF
Image Mount Utility

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    mount <image_path> <mount_point>    Mount a disk image
    unmount <device> <mount_point>      Unmount a disk image
    list                               List currently mounted images
    help                               Show this help message

OPTIONS:
    --debug                            Enable debug logging
    --log-file <path>                  Set custom log file path

EXAMPLES:
    $0 mount rpi.img /tmp/mount
    $0 unmount /dev/loop0 /tmp/mount
    $0 list

EOF
}

main() {
    init_logging
    detect_platform
    
    # Set up cleanup trap
    trap cleanup_mounts EXIT
    
    local command="${1:-help}"
    
    case "$command" in
        mount)
            if [[ $# -ne 3 ]]; then
                log_error "mount command requires 2 arguments: <image_path> <mount_point>"
                show_usage
                exit 1
            fi
            mount_image "$2" "$3"
            ;;
        unmount)
            if [[ $# -ne 3 ]]; then
                log_error "unmount command requires 2 arguments: <device> <mount_point>"
                show_usage
                exit 1
            fi
            unmount_image "$2" "$3"
            ;;
        list)
            list_mounted_images
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi