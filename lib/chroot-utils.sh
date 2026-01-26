#!/bin/bash

# Chroot Utilities
# Cross-platform utility for chroot environment setup and command execution
# Supports ARM emulation for x86 hosts

set -euo pipefail

# Global variables
# SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DETECTED_PLATFORM=""
LOG_FILE=""

# Initialize logging if not already set
init_logging() {
    if [[ -z "${LOG_FILE:-}" ]]; then
        LOG_FILE="${SCRIPT_DIR}/chroot-utils.log"
        echo "=== Chroot Utilities Started at $(date) ===" > "$LOG_FILE"
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

# Set up chroot environment for ARM emulation and package installation
# Usage: setup_chroot_environment <chroot_path>
# Returns: 0 on success, 1 on failure
setup_chroot_environment() {
    local chroot_path="$1"
    
    log_debug "Setting up chroot environment: $chroot_path"
    
    # Validate input
    if [[ -z "$chroot_path" ]]; then
        log_error "setup_chroot_environment: Missing chroot_path parameter"
        return 1
    fi
    
    if [[ ! -d "$chroot_path" ]]; then
        log_error "setup_chroot_environment: Chroot path does not exist: $chroot_path"
        return 1
    fi
    
    # Set up ARM emulation for x86 systems if needed
    local host_arch
    host_arch=$(uname -m)
    log_debug "Host architecture: $host_arch"
    
    if [[ "$host_arch" != "aarch64" && "$host_arch" != "arm64" ]]; then
        log_debug "Setting up ARM emulation for x86 host"
        
        # Check if qemu-user-static is available
        if [[ "$DETECTED_PLATFORM" == "linux" ]]; then
            if ! command -v qemu-aarch64-static >/dev/null 2>&1; then
                log_warn "qemu-user-static not found, ARM emulation may not work"
                log_warn "Install with: sudo apt-get install qemu-user-static"
            else
                # Copy qemu-aarch64-static to chroot if it exists
                local qemu_static_path="/usr/bin/qemu-aarch64-static"
                if [[ -f "$qemu_static_path" ]]; then
                    log_debug "Copying qemu-aarch64-static to chroot"
                    cp "$qemu_static_path" "${chroot_path}/usr/bin/" 2>/dev/null || {
                        log_warn "Failed to copy qemu-aarch64-static to chroot"
                    }
                fi
            fi
        fi
    fi
    
    # Mount essential filesystems for chroot
    log_debug "Mounting essential filesystems for chroot"
    
    # Mount /proc
    if [[ ! -d "${chroot_path}/proc" ]]; then
        mkdir -p "${chroot_path}/proc"
    fi
    
    if ! mountpoint -q "${chroot_path}/proc" 2>/dev/null; then
        if [[ "$DETECTED_PLATFORM" == "linux" ]]; then
            sudo mount -t proc proc "${chroot_path}/proc" || {
                log_warn "Failed to mount /proc in chroot"
            }
        fi
    fi
    
    # Mount /sys
    if [[ ! -d "${chroot_path}/sys" ]]; then
        mkdir -p "${chroot_path}/sys"
    fi
    
    if ! mountpoint -q "${chroot_path}/sys" 2>/dev/null; then
        if [[ "$DETECTED_PLATFORM" == "linux" ]]; then
            sudo mount -t sysfs sysfs "${chroot_path}/sys" || {
                log_warn "Failed to mount /sys in chroot"
            }
        fi
    fi
    
    # Mount /dev
    if [[ ! -d "${chroot_path}/dev" ]]; then
        mkdir -p "${chroot_path}/dev"
    fi
    
    if ! mountpoint -q "${chroot_path}/dev" 2>/dev/null; then
        if [[ "$DETECTED_PLATFORM" == "linux" ]]; then
            sudo mount --bind /dev "${chroot_path}/dev" || {
                log_warn "Failed to bind mount /dev in chroot"
            }
        fi
    fi
    
    # Set up DNS resolution in chroot
    if [[ -f "/etc/resolv.conf" ]]; then
        log_debug "Copying DNS configuration to chroot"
        cp /etc/resolv.conf "${chroot_path}/etc/resolv.conf" 2>/dev/null || {
            log_warn "Failed to copy DNS configuration to chroot"
        }
    fi
    
    log_debug "Chroot environment setup completed"
    return 0
}

# Execute command in chroot environment
# Usage: chroot_exec <chroot_path> <command>
# Returns: Command exit code
chroot_exec() {
    local chroot_path="$1"
    local command="$2"
    
    log_debug "Executing in chroot: $command"
    
    # Validate inputs
    if [[ -z "$chroot_path" || -z "$command" ]]; then
        log_error "chroot_exec: Missing required parameters"
        return 1
    fi
    
    if [[ ! -d "$chroot_path" ]]; then
        log_error "chroot_exec: Chroot path does not exist: $chroot_path"
        return 1
    fi
    
    # Execute command in chroot environment
    case "$DETECTED_PLATFORM" in
        linux)
            sudo chroot "$chroot_path" /bin/bash -c "$command"
            ;;
        macos)
            # macOS doesn't have chroot in the same way, so we'll use a different approach
            log_warn "chroot_exec: macOS chroot support is limited"
            # For macOS, we might need to use different approaches or warn about limitations
            return 1
            ;;
        *)
            log_error "chroot_exec: Unsupported platform: $DETECTED_PLATFORM"
            return 1
            ;;
    esac
}

# Cleanup chroot mounts
# Usage: cleanup_chroot_mounts <chroot_path>
# Returns: 0 on success, 1 on failure
cleanup_chroot_mounts() {
    local chroot_path="$1"
    
    log_debug "Cleaning up chroot mounts: $chroot_path"
    
    if [[ -z "$chroot_path" ]]; then
        log_error "cleanup_chroot_mounts: Missing chroot_path parameter"
        return 1
    fi
    
    if [[ "$DETECTED_PLATFORM" == "linux" ]]; then
        # Unmount in reverse order
        for mount_point in dev sys proc; do
            if mountpoint -q "${chroot_path}/${mount_point}" 2>/dev/null; then
                log_debug "Unmounting ${chroot_path}/${mount_point}"
                sudo umount "${chroot_path}/${mount_point}" 2>/dev/null || {
                    log_warn "Failed to unmount ${chroot_path}/${mount_point}"
                }
            fi
        done
    fi
    
    log_debug "Chroot cleanup completed"
    return 0
}

# Show usage information
show_usage() {
    cat << EOF
USAGE: $(basename "$0") <command> [options]

Chroot utilities for cross-platform ARM emulation and command execution.

COMMANDS:
    setup <chroot_path>           Set up chroot environment with ARM emulation
    exec <chroot_path> <command>  Execute command in chroot environment
    cleanup <chroot_path>         Clean up chroot mounts
    help                          Show this help message

EXAMPLES:
    # Set up chroot environment
    $(basename "$0") setup /mnt/rpi

    # Execute command in chroot
    $(basename "$0") exec /mnt/rpi "apt-get update"

    # Clean up mounts
    $(basename "$0") cleanup /mnt/rpi

ENVIRONMENT:
    DEBUG=1                       Enable debug logging

NOTES:
    - Requires Linux platform for full functionality
    - macOS has limited chroot support
    - Requires sudo privileges for mount operations
    - Automatically sets up ARM emulation on x86 hosts

EOF
}

# Main CLI interface
main() {
    local command="${1:-}"
    
    # Initialize
    init_logging
    detect_platform
    
    case "$command" in
        setup)
            if [[ $# -lt 2 ]]; then
                log_error "Missing chroot_path parameter"
                show_usage
                exit 1
            fi
            setup_chroot_environment "$2"
            ;;
        exec)
            if [[ $# -lt 3 ]]; then
                log_error "Missing chroot_path or command parameter"
                show_usage
                exit 1
            fi
            chroot_exec "$2" "$3"
            ;;
        cleanup)
            if [[ $# -lt 2 ]]; then
                log_error "Missing chroot_path parameter"
                show_usage
                exit 1
            fi
            cleanup_chroot_mounts "$2"
            ;;
        help|--help|-h|"")
            show_usage
            exit 0
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
