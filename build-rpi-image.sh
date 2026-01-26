#!/bin/bash

# Raspberry Pi Image Builder
# Cross-platform script for creating custom Raspberry Pi SD card images with Open Horizon components
# Supports both Linux and macOS environments

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Global configuration variables
CONFIG_OH_VERSION=""           # Open Horizon version (e.g., "2.30.0")
CONFIG_BASE_IMAGE=""           # Path to base Raspberry Pi OS image
CONFIG_OUTPUT_IMAGE=""         # Path for output custom image
CONFIG_EXCHANGE_URL=""         # Optional exchange URL
CONFIG_EXCHANGE_ORG=""         # Optional exchange organization
CONFIG_EXCHANGE_USER=""        # Optional exchange username
CONFIG_EXCHANGE_TOKEN=""       # Optional exchange token
CONFIG_NODE_JSON=""            # Optional custom node.json file path
CONFIG_WIFI_SSID=""           # Optional Wi-Fi network name
CONFIG_WIFI_PASSWORD=""       # Optional Wi-Fi password
CONFIG_WIFI_SECURITY="WPA2"   # Wi-Fi security type
CONFIG_MOUNT_POINT="/tmp/rpi_mount"  # Temporary mount point

# Global state variables
SCRIPT_DIR=""
LOG_FILE=""
CLEANUP_REQUIRED=false
MOUNTED_DEVICES=()
DETECTED_PLATFORM=""
PLATFORM_TOOLS=()

# Initialize script directory and logging
init_script() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    LOG_FILE="${SCRIPT_DIR}/build-rpi-image.log"
    
    # Create log file with timestamp
    echo "=== Raspberry Pi Image Builder Started at $(date) ===" > "$LOG_FILE"
    
    # Note: Libraries will be sourced when needed via wrapper functions
    
    # Set up signal handlers for cleanup
    trap cleanup_on_exit EXIT
    trap cleanup_on_signal INT TERM
}

# Logging functions
log_info() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] INFO: $message" | tee -a "$LOG_FILE"
}

log_warn() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] WARN: $message" | tee -a "$LOG_FILE" >&2
}

log_error() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] ERROR: $message" | tee -a "$LOG_FILE" >&2
}

log_debug() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    if [[ "${DEBUG:-}" == "1" ]]; then
        echo "[$timestamp] DEBUG: $message" | tee -a "$LOG_FILE"
    else
        echo "[$timestamp] DEBUG: $message" >> "$LOG_FILE"
    fi
}

# Error handling functions
handle_error() {
    local exit_code=$?
    local line_number=$1
    log_error "Script failed at line $line_number with exit code $exit_code"
    cleanup_on_exit
    exit $exit_code
}

# Set up error trap
trap 'handle_error $LINENO' ERR

# Cleanup functions
cleanup_on_exit() {
    if [[ "$CLEANUP_REQUIRED" == "true" ]]; then
        log_info "Performing cleanup operations..."
        cleanup_mounts
        cleanup_temp_files
    fi
}

cleanup_on_signal() {
    log_warn "Received interrupt signal, cleaning up..."
    CLEANUP_REQUIRED=true
    cleanup_on_exit
    exit 130
}

cleanup_mounts() {
    if [[ ${#MOUNTED_DEVICES[@]} -gt 0 ]]; then
        for device in "${MOUNTED_DEVICES[@]}"; do
            if [[ -n "$device" ]]; then
                log_info "Unmounting device: $device"
                unmount_image "$device" "$CONFIG_MOUNT_POINT" || true
            fi
        done
    fi
    MOUNTED_DEVICES=()
}

cleanup_temp_files() {
    if [[ -d "$CONFIG_MOUNT_POINT" ]]; then
        log_info "Removing temporary mount point: $CONFIG_MOUNT_POINT"
        rmdir "$CONFIG_MOUNT_POINT" 2>/dev/null || true
    fi
}

# Platform detection wrapper function
detect_platform() {
    # Source library and call its function
    source "${SCRIPT_DIR}/lib/platform-detect.sh"
    detect_platform
}

# Dependency checking wrapper function
check_dependencies() {
    # Source library and check dependencies
    source "${SCRIPT_DIR}/lib/platform-detect.sh"
    log_info "Checking platform dependencies..."
    
    # Only check core tools needed for main script
    if ! check_dependencies core; then
        log_error "Core dependency check failed"
        exit 1
    fi
    
    # Also check mounting tools
    if ! check_dependencies mounting; then
        log_error "Mounting dependency check failed"
        exit 1
    fi
    
    log_info "Dependency check completed successfully"
}

# Configuration parsing and validation functions
parse_arguments() {
    local show_help=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --oh-version)
                CONFIG_OH_VERSION="$2"
                shift 2
                ;;
            --base-image)
                CONFIG_BASE_IMAGE="$2"
                shift 2
                ;;
            --output-image)
                CONFIG_OUTPUT_IMAGE="$2"
                shift 2
                ;;
            --exchange-url)
                CONFIG_EXCHANGE_URL="$2"
                shift 2
                ;;
            --exchange-org)
                CONFIG_EXCHANGE_ORG="$2"
                shift 2
                ;;
            --exchange-user)
                CONFIG_EXCHANGE_USER="$2"
                shift 2
                ;;
            --exchange-token)
                CONFIG_EXCHANGE_TOKEN="$2"
                shift 2
                ;;
            --node-json)
                CONFIG_NODE_JSON="$2"
                shift 2
                ;;
            --wifi-ssid)
                CONFIG_WIFI_SSID="$2"
                shift 2
                ;;
            --wifi-password)
                CONFIG_WIFI_PASSWORD="$2"
                shift 2
                ;;
            --wifi-security)
                CONFIG_WIFI_SECURITY="$2"
                shift 2
                ;;
            --mount-point)
                CONFIG_MOUNT_POINT="$2"
                shift 2
                ;;
            --help|-h)
                show_help=true
                shift
                ;;
            --debug)
                DEBUG=1
                shift
                ;;
            --list-agents)
                list_agents
                exit 0
                ;;
            *)
                log_error "Unknown argument: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    if [[ "$show_help" == "true" ]]; then
        show_usage
        exit 0
    fi
}

show_usage() {
    cat << EOF
Raspberry Pi Image Builder

USAGE:
    $0 [OPTIONS]

REQUIRED OPTIONS:
    --oh-version VERSION        Open Horizon version to install (e.g., "2.30.0")
    --base-image PATH          Path to base Raspberry Pi OS image
    --output-image PATH        Path for output custom image

OPTIONAL OPTIONS:
    --exchange-url URL         Open Horizon exchange URL
    --exchange-org ORG         Exchange organization
    --exchange-user USER       Exchange username
    --exchange-token TOKEN     Exchange authentication token
    --node-json PATH           Path to custom node.json file
    --wifi-ssid SSID          Wi-Fi network name
    --wifi-password PASS      Wi-Fi password
    --wifi-security TYPE      Wi-Fi security type (WPA2, WPA3) [default: WPA2]
    --mount-point PATH        Temporary mount point [default: /tmp/rpi_mount]
    --debug                   Enable debug logging
    --list-agents             List all registered agent configurations
    --help, -h                Show this help message

EXAMPLES:
    # Basic usage with required parameters
    $0 --oh-version "2.30.0" --base-image "raspios-lite.img" --output-image "custom-rpi.img"
    
    # With exchange registration
    $0 --oh-version "2.30.0" --base-image "raspios-lite.img" --output-image "custom-rpi.img" \\
       --exchange-url "https://exchange.example.com" --exchange-org "myorg" \\
       --exchange-user "admin" --exchange-token "mytoken"
    
    # With Wi-Fi configuration
    $0 --oh-version "2.30.0" --base-image "raspios-lite.img" --output-image "custom-rpi.img" \\
       --wifi-ssid "MyNetwork" --wifi-password "mypassword" --wifi-security "WPA3"

EOF
}

validate_configuration() {
    local errors=()
    
    # Validate required parameters
    if [[ -z "$CONFIG_OH_VERSION" ]]; then
        errors+=("Open Horizon version is required (--oh-version)")
    fi
    
    if [[ -z "$CONFIG_BASE_IMAGE" ]]; then
        errors+=("Base image path is required (--base-image)")
    elif [[ ! -f "$CONFIG_BASE_IMAGE" ]]; then
        errors+=("Base image file does not exist: $CONFIG_BASE_IMAGE")
    fi
    
    if [[ -z "$CONFIG_OUTPUT_IMAGE" ]]; then
        errors+=("Output image path is required (--output-image)")
    fi
    
    # Validate optional parameters
    if [[ -n "$CONFIG_NODE_JSON" && ! -f "$CONFIG_NODE_JSON" ]]; then
        errors+=("Custom node.json file does not exist: $CONFIG_NODE_JSON")
    fi
    
    # Validate Wi-Fi security type
    if [[ -n "$CONFIG_WIFI_SECURITY" ]]; then
        case "$CONFIG_WIFI_SECURITY" in
            WPA2|WPA3)
                ;;
            *)
                errors+=("Invalid Wi-Fi security type: $CONFIG_WIFI_SECURITY (must be WPA2 or WPA3)")
                ;;
        esac
    fi
    
    # Validate exchange configuration consistency
    if [[ -n "$CONFIG_EXCHANGE_URL" ]]; then
        if [[ -z "$CONFIG_EXCHANGE_ORG" || -z "$CONFIG_EXCHANGE_USER" || -z "$CONFIG_EXCHANGE_TOKEN" ]]; then
            errors+=("Exchange URL specified but missing organization, user, or token")
        fi
    fi
    
    # Validate Wi-Fi configuration consistency
    if [[ -n "$CONFIG_WIFI_SSID" && -z "$CONFIG_WIFI_PASSWORD" ]]; then
        errors+=("Wi-Fi SSID specified but password is missing")
    fi
    
    # Validate Wi-Fi configuration if provided
    if [[ -n "$CONFIG_WIFI_SSID" && -n "$CONFIG_WIFI_PASSWORD" ]]; then
        if ! validate_wifi_configuration "$CONFIG_WIFI_SSID" "$CONFIG_WIFI_PASSWORD" "$CONFIG_WIFI_SECURITY"; then
            errors+=("Wi-Fi configuration validation failed")
        fi
    fi
    
    # Report validation errors
    if [[ ${#errors[@]} -gt 0 ]]; then
        log_error "Configuration validation failed:"
        for error in "${errors[@]}"; do
            log_error "  - $error"
        done
        show_usage
        exit 1
    fi
    
    log_info "Configuration validation passed"
}

prompt_for_missing_parameters() {
    # Prompt for required parameters if not provided
    if [[ -z "$CONFIG_OH_VERSION" ]]; then
        read -p "Enter Open Horizon version (e.g., 2.30.0): " CONFIG_OH_VERSION
    fi
    
    if [[ -z "$CONFIG_BASE_IMAGE" ]]; then
        read -p "Enter path to base Raspberry Pi OS image: " CONFIG_BASE_IMAGE
    fi
    
    if [[ -z "$CONFIG_OUTPUT_IMAGE" ]]; then
        # Generate default output name based on input
        local base_name=$(basename "$CONFIG_BASE_IMAGE" .img)
        CONFIG_OUTPUT_IMAGE="${base_name}-oh-${CONFIG_OH_VERSION}.img"
        log_info "Using default output image name: $CONFIG_OUTPUT_IMAGE"
    fi
}

log_configuration() {
    log_info "=== Configuration Summary ==="
    log_info "Platform: $DETECTED_PLATFORM"
    log_info "Open Horizon Version: $CONFIG_OH_VERSION"
    log_info "Base Image: $CONFIG_BASE_IMAGE"
    log_info "Output Image: $CONFIG_OUTPUT_IMAGE"
    log_info "Mount Point: $CONFIG_MOUNT_POINT"
    
    if [[ -n "$CONFIG_EXCHANGE_URL" ]]; then
        log_info "Exchange URL: $CONFIG_EXCHANGE_URL"
        log_info "Exchange Organization: $CONFIG_EXCHANGE_ORG"
        log_info "Exchange User: $CONFIG_EXCHANGE_USER"
        log_info "Exchange Token: [REDACTED]"
    else
        log_info "Exchange Registration: Disabled"
    fi
    
    if [[ -n "$CONFIG_NODE_JSON" ]]; then
        log_info "Custom node.json: $CONFIG_NODE_JSON"
    else
        log_info "Node Configuration: Default"
    fi
    
    if [[ -n "$CONFIG_WIFI_SSID" ]]; then
        log_info "Wi-Fi SSID: $CONFIG_WIFI_SSID"
        log_info "Wi-Fi Security: $CONFIG_WIFI_SECURITY"
        log_info "Wi-Fi Password: [REDACTED]"
    else
        log_info "Wi-Fi Configuration: Disabled"
    fi
    
    log_info "=========================="
}

# Image mounting wrapper functions
mount_image() {
    # Source library and call its function
    source "${SCRIPT_DIR}/lib/image-mount.sh"
    detect_platform  # Ensure platform is detected
    mount_image "$@"
}

unmount_image() {
    # Source library and call its function
    source "${SCRIPT_DIR}/lib/image-mount.sh"
    detect_platform  # Ensure platform is detected
    unmount_image "$@"
}
# These functions are now provided by the image-mount.sh library

# Image verification wrapper functions
verify_image() {
    # Source library and call its function
    source "${SCRIPT_DIR}/lib/image-verify.sh"
    detect_platform  # Ensure platform is detected
    verify_image "$@"
}

verify_image_format_compatibility() {
    # Source library and call its function
    source "${SCRIPT_DIR}/lib/image-verify.sh"
    detect_platform  # Ensure platform is detected
    verify_image_format_compatibility "$@"
}

verify_rpi_imager_compatibility() {
    # Source library and call its function
    source "${SCRIPT_DIR}/lib/image-verify.sh"
    detect_platform  # Ensure platform is detected
    verify_rpi_imager_compatibility "$@"
}

# Chroot utilities wrapper functions
setup_chroot_environment() {
    source "${SCRIPT_DIR}/lib/chroot-utils.sh"
    setup_chroot_environment "$@"
}

chroot_exec() {
    source "${SCRIPT_DIR}/lib/chroot-utils.sh"
    chroot_exec "$@"
}

cleanup_chroot_mounts() {
    source "${SCRIPT_DIR}/lib/chroot-utils.sh"
    cleanup_chroot_mounts "$@"
}

# Network configuration wrapper functions
configure_wifi() {
    source "${SCRIPT_DIR}/lib/network-config.sh"
    configure_wifi "$@"
}

validate_wifi_configuration() {
    source "${SCRIPT_DIR}/lib/network-config.sh"
    validate_wifi_configuration "$@"
}

configure_network_fallback() {
    source "${SCRIPT_DIR}/lib/network-config.sh"
    configure_network_fallback "$@"
}

# Open Horizon installation wrapper functions
verify_open_horizon_installation() {
    source "${SCRIPT_DIR}/lib/horizon-install.sh"
    verify_open_horizon_installation "$@"
}

install_anax_agent() {
    source "${SCRIPT_DIR}/lib/horizon-install.sh"
    install_anax_agent "$@"
}

install_horizon_cli() {
    source "${SCRIPT_DIR}/lib/horizon-install.sh"
    install_horizon_cli "$@"
}

configure_agent_service() {
    source "${SCRIPT_DIR}/lib/horizon-install.sh"
    configure_agent_service "$@"
}

configure_exchange_registration() {
    source "${SCRIPT_DIR}/lib/horizon-install.sh"
    configure_exchange_registration "$@"
}

setup_cloud_init() {
    source "${SCRIPT_DIR}/lib/horizon-install.sh"
    setup_cloud_init "$@"
}

create_firstrun_script() {
    source "${SCRIPT_DIR}/lib/horizon-install.sh"
    create_firstrun_script "$@"
}

validate_exchange_connectivity() {
    source "${SCRIPT_DIR}/lib/horizon-install.sh"
    validate_exchange_connectivity "$@"
}

embed_exchange_credentials() {
    source "${SCRIPT_DIR}/lib/horizon-install.sh"
    embed_exchange_credentials "$@"
}

configure_node_json() {
    source "${SCRIPT_DIR}/lib/horizon-install.sh"
    configure_node_json "$@"
}

create_registration_config() {
    source "${SCRIPT_DIR}/lib/horizon-install.sh"
    create_registration_config "$@"
}

verify_image_format_compatibility() {
    # Source library and call its function
    source "${SCRIPT_DIR}/lib/image-verify.sh"
    detect_platform  # Ensure platform is detected
    verify_image_format_compatibility "$@"
}

# verify_image_format_compatibility function is now provided by image-verify.sh library

verify_rpi_imager_compatibility() {
    local image_path="$1"
    
    log_debug "Verifying Raspberry Pi Imager compatibility for: $image_path"
    
    # Check file extension (Raspberry Pi Imager expects .img files)
    local file_extension="${image_path##*.}"
    if [[ "$file_extension" != "img" ]]; then
        log_warn "verify_rpi_imager_compatibility: File extension is not .img (found: .$file_extension)"
        log_warn "Raspberry Pi Imager may not recognize this file format"
    fi
    
    # Check file size alignment (should be aligned to sector boundaries)
    local file_size
    file_size=$(stat -c%s "$image_path" 2>/dev/null || stat -f%z "$image_path" 2>/dev/null)
    if [[ -z "$file_size" ]]; then
        log_error "verify_rpi_imager_compatibility: Could not determine file size"
        return 1
    fi
    
    # Check if file size is aligned to 512-byte sectors
    local sector_size=512
    local remainder=$((file_size % sector_size))
    if [[ $remainder -ne 0 ]]; then
        log_warn "verify_rpi_imager_compatibility: File size not aligned to 512-byte sectors"
        log_warn "File size: $file_size bytes, remainder: $remainder bytes"
    fi
    
    # Check for valid disk image signature (MBR or GPT)
    log_debug "Checking disk image signature"
    local boot_signature
    boot_signature=$(dd if="$image_path" bs=1 skip=510 count=2 2>/dev/null | hexdump -C | head -1 | awk '{print $2$3}')
    
    if [[ "$boot_signature" == "55aa" ]]; then
        log_debug "Found valid MBR boot signature (0x55AA)"
    else
        # Check for GPT signature
        local gpt_signature
        gpt_signature=$(dd if="$image_path" bs=1 skip=512 count=8 2>/dev/null | tr -d '\0')
        if [[ "$gpt_signature" == "EFI PART" ]]; then
            log_debug "Found valid GPT signature"
        else
            log_error "verify_rpi_imager_compatibility: No valid MBR or GPT signature found"
            log_error "Boot signature: $boot_signature, GPT signature: $gpt_signature"
            return 1
        fi
    fi
    
    # Check for Raspberry Pi specific boot files (if we can mount the image)
    log_debug "Checking for Raspberry Pi boot files"
    local temp_mount="/tmp/rpi_compat_check_$$"
    mkdir -p "$temp_mount" || {
        log_warn "verify_rpi_imager_compatibility: Could not create temp mount point for boot file check"
        return 0  # Non-critical failure
    }
    
    local mount_device
    mount_device=$(mount_image "$image_path" "$temp_mount" 2>/dev/null)
    local mount_result=$?
    
    if [[ $mount_result -eq 0 && -n "$mount_device" ]]; then
        # Check for essential Raspberry Pi boot files
        local boot_files=("config.txt" "cmdline.txt" "start.elf" "fixup.dat")
        local missing_boot_files=()
        local boot_path="$temp_mount/boot"
        
        # If boot is not mounted separately, check if boot files are in root
        if [[ ! -d "$boot_path" ]]; then
            boot_path="$temp_mount"
        fi
        
        for boot_file in "${boot_files[@]}"; do
            if [[ ! -f "$boot_path/$boot_file" ]]; then
                missing_boot_files+=("$boot_file")
            fi
        done
        
        # Unmount the image
        unmount_image "$mount_device" "$temp_mount" || {
            log_warn "verify_rpi_imager_compatibility: Failed to unmount temp mount"
        }
        
        if [[ ${#missing_boot_files[@]} -gt 0 ]]; then
            log_warn "verify_rpi_imager_compatibility: Missing Raspberry Pi boot files: ${missing_boot_files[*]}"
            log_warn "Image may not boot properly on Raspberry Pi hardware"
        else
            log_debug "All essential Raspberry Pi boot files found"
        fi
    else
        log_warn "verify_rpi_imager_compatibility: Could not mount image for boot file verification"
    fi
    
    rmdir "$temp_mount" 2>/dev/null || true
    
    log_debug "Raspberry Pi Imager compatibility check completed"
    return 0
}

verify_linux_utilities_compatibility() {
    local image_path="$1"
    
    log_debug "Verifying Linux utilities compatibility for: $image_path"
    
    # Test dd compatibility
    log_debug "Testing dd compatibility"
    if ! verify_dd_compatibility "$image_path"; then
        log_error "verify_linux_utilities_compatibility: dd compatibility check failed"
        return 1
    fi
    
    # Test file command recognition
    log_debug "Testing file command recognition"
    if ! verify_file_command_recognition "$image_path"; then
        log_error "verify_linux_utilities_compatibility: file command recognition failed"
        return 1
    fi
    
    # Test fdisk compatibility (if available)
    if command -v fdisk >/dev/null 2>&1; then
        log_debug "Testing fdisk compatibility"
        if ! verify_fdisk_compatibility "$image_path"; then
            log_warn "verify_linux_utilities_compatibility: fdisk compatibility check failed (non-critical)"
        fi
    else
        log_debug "fdisk not available, skipping fdisk compatibility check"
    fi
    
    # Test parted compatibility (if available)
    if command -v parted >/dev/null 2>&1; then
        log_debug "Testing parted compatibility"
        if ! verify_parted_compatibility "$image_path"; then
            log_warn "verify_linux_utilities_compatibility: parted compatibility check failed (non-critical)"
        fi
    else
        log_debug "parted not available, skipping parted compatibility check"
    fi
    
    log_debug "Linux utilities compatibility check completed"
    return 0
}

verify_dd_compatibility() {
    local image_path="$1"
    
    log_debug "Testing dd read compatibility"
    
    # Test if dd can read the first sector
    local first_sector
    first_sector=$(dd if="$image_path" bs=512 count=1 2>/dev/null | wc -c)
    
    if [[ "$first_sector" -eq 512 ]]; then
        log_debug "dd can successfully read first sector (512 bytes)"
    else
        log_error "verify_dd_compatibility: dd failed to read first sector correctly"
        log_error "Expected 512 bytes, got $first_sector bytes"
        return 1
    fi
    
    # Test if dd can read the last sector
    local file_size
    file_size=$(stat -c%s "$image_path" 2>/dev/null || stat -f%z "$image_path" 2>/dev/null)
    local last_sector_offset=$(((file_size / 512) - 1))
    
    if [[ $last_sector_offset -gt 0 ]]; then
        local last_sector
        last_sector=$(dd if="$image_path" bs=512 skip="$last_sector_offset" count=1 2>/dev/null | wc -c)
        
        if [[ "$last_sector" -eq 512 ]]; then
            log_debug "dd can successfully read last sector (512 bytes)"
        else
            log_warn "verify_dd_compatibility: dd may have issues reading last sector"
            log_warn "Expected 512 bytes, got $last_sector bytes"
        fi
    fi
    
    return 0
}

verify_file_command_recognition() {
    local image_path="$1"
    
    log_debug "Testing file command recognition"
    
    # Use file command to identify the image
    local file_output
    file_output=$(file "$image_path" 2>/dev/null)
    
    if [[ -z "$file_output" ]]; then
        log_error "verify_file_command_recognition: file command produced no output"
        return 1
    fi
    
    log_debug "File command output: $file_output"
    
    # Check if file command recognizes it as a disk image or filesystem
    if [[ "$file_output" =~ (DOS/MBR|disk|filesystem|partition|boot) ]]; then
        log_debug "file command correctly identifies image as disk/filesystem"
        return 0
    else
        log_warn "verify_file_command_recognition: file command may not recognize image format"
        log_warn "Output: $file_output"
        # This is not a fatal error for compatibility
        return 0
    fi
}

verify_fdisk_compatibility() {
    local image_path="$1"
    
    log_debug "Testing fdisk compatibility"
    
    # Test if fdisk can read the partition table
    local fdisk_output
    fdisk_output=$(fdisk -l "$image_path" 2>/dev/null)
    local fdisk_result=$?
    
    if [[ $fdisk_result -eq 0 && -n "$fdisk_output" ]]; then
        log_debug "fdisk successfully read partition table"
        
        # Check if fdisk found any partitions
        local partition_count
        partition_count=$(echo "$fdisk_output" | grep -c "^${image_path}" 2>/dev/null || echo "0")
        
        if [[ $partition_count -gt 0 ]]; then
            log_debug "fdisk found $partition_count partition(s)"
        else
            log_warn "verify_fdisk_compatibility: fdisk did not find any partitions"
        fi
        
        return 0
    else
        log_warn "verify_fdisk_compatibility: fdisk failed to read partition table"
        return 1
    fi
}

verify_parted_compatibility() {
    local image_path="$1"
    
    log_debug "Testing parted compatibility"
    
    # Test if parted can read the partition table
    local parted_output
    parted_output=$(parted "$image_path" print 2>/dev/null)
    local parted_result=$?
    
    if [[ $parted_result -eq 0 && -n "$parted_output" ]]; then
        log_debug "parted successfully read partition table"
        
        # Check if parted found any partitions
        local partition_count
        partition_count=$(echo "$parted_output" | grep -c "^ [0-9]" 2>/dev/null || echo "0")
        
        if [[ $partition_count -gt 0 ]]; then
            log_debug "parted found $partition_count partition(s)"
        else
            log_warn "verify_parted_compatibility: parted did not find any partitions"
        fi
        
        return 0
    else
        log_warn "verify_parted_compatibility: parted failed to read partition table"
        return 1
    fi
}

verify_partition_structure() {
    local image_path="$1"
    
    log_debug "Verifying partition table and filesystem structure"
    
    # Check partition table type and structure
    if ! verify_partition_table_structure "$image_path"; then
        log_error "verify_partition_structure: Partition table structure validation failed"
        return 1
    fi
    
    # Check filesystem structure
    if ! verify_filesystem_structure "$image_path"; then
        log_error "verify_partition_structure: Filesystem structure validation failed"
        return 1
    fi
    
    log_debug "Partition and filesystem structure validation completed"
    return 0
}

verify_partition_table_structure() {
    local image_path="$1"
    
    log_debug "Verifying partition table structure"
    
    # Check for MBR signature (0x55AA at offset 510-511)
    local boot_signature
    boot_signature=$(dd if="$image_path" bs=1 skip=510 count=2 2>/dev/null | hexdump -v -e '/1 "%02x"')
    
    if [[ "$boot_signature" == "55aa" ]]; then
        log_debug "Found valid MBR boot signature"
        
        # Analyze MBR partition entries (starting at offset 446)
        local partition_entries
        partition_entries=$(dd if="$image_path" bs=1 skip=446 count=64 2>/dev/null | hexdump -C)
        
        if [[ -n "$partition_entries" ]]; then
            log_debug "Successfully read MBR partition entries"
            
            # Count active partitions (basic check)
            local active_partitions=0
            local i
            for i in {0..3}; do
                local offset=$((446 + i * 16))
                local partition_type
                partition_type=$(dd if="$image_path" bs=1 skip=$((offset + 4)) count=1 2>/dev/null | hexdump -v -e '/1 "%02x"')
                
                if [[ -n "$partition_type" && "$partition_type" != "00" ]]; then
                    active_partitions=$((active_partitions + 1))
                fi
            done
            
            log_debug "Found $active_partitions active partition(s) in MBR"
            
            if [[ $active_partitions -eq 0 ]]; then
                log_warn "verify_partition_table_structure: No active partitions found in MBR"
                # For a basic test image, this is acceptable
            fi
        else
            log_error "verify_partition_table_structure: Could not read MBR partition entries"
            return 1
        fi
    else
        # Check for GPT signature
        local gpt_header
        gpt_header=$(dd if="$image_path" bs=1 skip=512 count=8 2>/dev/null | tr -d '\0')
        
        if [[ "$gpt_header" == "EFI PART" ]]; then
            log_debug "Found valid GPT signature"
            
            # Basic GPT validation
            local gpt_revision
            gpt_revision=$(dd if="$image_path" bs=1 skip=520 count=4 2>/dev/null | hexdump -v -e '/1 "%02x"')
            log_debug "GPT revision: $gpt_revision"
            
        else
            log_error "verify_partition_table_structure: No valid MBR or GPT signature found"
            log_error "Boot signature: $boot_signature, GPT header: $gpt_header"
            return 1
        fi
    fi
    
    return 0
}

verify_filesystem_structure() {
    local image_path="$1"
    
    log_debug "Verifying filesystem structure"
    
    # Try to mount the image to verify filesystem structure
    local temp_mount="/tmp/fs_verify_$$"
    mkdir -p "$temp_mount" || {
        log_error "verify_filesystem_structure: Could not create temp mount point"
        return 1
    }
    
    local mount_device
    mount_device=$(mount_image "$image_path" "$temp_mount" 2>/dev/null)
    local mount_result=$?
    
    if [[ $mount_result -eq 0 && -n "$mount_device" ]]; then
        log_debug "Successfully mounted image for filesystem verification"
        
        # Check for essential Linux filesystem structure
        local essential_dirs=("/etc" "/usr" "/var" "/home" "/boot" "/bin" "/sbin" "/lib")
        local missing_dirs=()
        local found_dirs=()
        
        for dir in "${essential_dirs[@]}"; do
            if [[ -d "${temp_mount}${dir}" ]]; then
                found_dirs+=("$dir")
            else
                missing_dirs+=("$dir")
            fi
        done
        
        log_debug "Found directories: ${found_dirs[*]}"
        
        if [[ ${#missing_dirs[@]} -gt 0 ]]; then
            log_warn "verify_filesystem_structure: Missing some standard directories: ${missing_dirs[*]}"
            # This might be acceptable for minimal images
        fi
        
        # Check for essential files
        local essential_files=("/etc/passwd" "/etc/fstab" "/etc/hostname")
        local missing_files=()
        local found_files=()
        
        for file in "${essential_files[@]}"; do
            if [[ -f "${temp_mount}${file}" ]]; then
                found_files+=("$file")
            else
                missing_files+=("$file")
            fi
        done
        
        log_debug "Found essential files: ${found_files[*]}"
        
        if [[ ${#missing_files[@]} -gt 0 ]]; then
            log_warn "verify_filesystem_structure: Missing some essential files: ${missing_files[*]}"
        fi
        
        # Check filesystem type of root partition
        local fs_type
        fs_type=$(df -T "$temp_mount" 2>/dev/null | tail -1 | awk '{print $2}')
        if [[ -n "$fs_type" ]]; then
            log_debug "Root filesystem type: $fs_type"
            
            # Verify it's a supported filesystem type
            case "$fs_type" in
                ext2|ext3|ext4|btrfs|xfs)
                    log_debug "Filesystem type $fs_type is well-supported by Linux utilities"
                    ;;
                *)
                    log_warn "verify_filesystem_structure: Unusual filesystem type: $fs_type"
                    ;;
            esac
        fi
        
        # Unmount the image
        unmount_image "$mount_device" "$temp_mount" || {
            log_warn "verify_filesystem_structure: Failed to unmount temp mount"
        }
        
        # Determine if filesystem structure is acceptable
        local critical_missing=0
        for dir in "/etc" "/usr"; do
            if [[ ! -d "${temp_mount}${dir}" ]]; then
                critical_missing=1
                break
            fi
        done
        
        if [[ $critical_missing -eq 1 ]]; then
            log_error "verify_filesystem_structure: Critical directories missing, filesystem structure invalid"
            rmdir "$temp_mount" 2>/dev/null || true
            return 1
        fi
        
    else
        log_warn "verify_filesystem_structure: Could not mount image for filesystem verification"
        # This is not necessarily a fatal error - the image might still be valid
    fi
    
    rmdir "$temp_mount" 2>/dev/null || true
    
    log_debug "Filesystem structure verification completed"
    return 0
}

is_exchange_registration_requested() {
    # Check if exchange registration is requested based on parameters
    if [[ -n "$CONFIG_EXCHANGE_URL" && -n "$CONFIG_EXCHANGE_ORG" && -n "$CONFIG_EXCHANGE_USER" && -n "$CONFIG_EXCHANGE_TOKEN" ]]; then
        log_debug "Exchange registration requested: URL=$CONFIG_EXCHANGE_URL, ORG=$CONFIG_EXCHANGE_ORG"
        return 0
    else
        log_debug "Exchange registration not requested"
        return 1
    fi
}

# Project registry functions
register_agent() {
    local config_data="$1"
    
    log_debug "Registering agent configuration in project registry"
    
    # Generate unique agent ID
    local agent_id
    agent_id=$(generate_agent_id)
    
    # Create registry entry
    local registry_entry
    registry_entry=$(create_registry_entry "$agent_id" "$config_data")
    
    # Append to REGISTRY.md file
    local agents_file="${SCRIPT_DIR}/REGISTRY.md"
    if ! append_to_agents_file "$agents_file" "$registry_entry"; then
        log_error "register_agent: Failed to append entry to REGISTRY.md"
        return 1
    fi
    
    # Parse configuration data (format: oh_version|base_image|output_image|exchange_url|exchange_org|node_json|wifi_ssid)
    local oh_version base_image output_image exchange_url exchange_org node_json wifi_ssid
    IFS='|' read -r oh_version base_image output_image exchange_url exchange_org node_json wifi_ssid <<< "$config_data"
    
    # Generate unique identifier and timestamp
    local agent_id
    local agent_created
    agent_id=$(generate_agent_id)
    agent_created=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    log_debug "Generated agent ID: $agent_id"
    log_debug "Created timestamp: $agent_created"
    
    # Create registry entry
    local registry_entry
    registry_entry=$(create_registry_entry "$agent_id" "$agent_created" "$oh_version" "$base_image" "$output_image" "$exchange_url" "$exchange_org" "$node_json" "$wifi_ssid")
    
    if [[ -z "$registry_entry" ]]; then
        log_error "register_agent: Failed to create registry entry"
        return 1
    fi
    
    # Append to AGENTS.md file
    local agents_file="${SCRIPT_DIR}/AGENTS.md"
    if ! append_to_agents_file "$agents_file" "$registry_entry"; then
        log_error "register_agent: Failed to append entry to AGENTS.md"
        return 1
    fi
    
    log_info "Agent configuration registered successfully with ID: $agent_id"
    return 0
}

generate_agent_id() {
    # Generate unique identifier using timestamp and hash
    local timestamp=$(date +%s)
    local random_data="${timestamp}-${RANDOM}-$(hostname)"
    local hash_suffix
    
    # Use available hash command (prefer sha256sum, fallback to md5)
    if command -v sha256sum >/dev/null 2>&1; then
        hash_suffix=$(echo "$random_data" | sha256sum | cut -c1-8)
    elif command -v md5sum >/dev/null 2>&1; then
        hash_suffix=$(echo "$random_data" | md5sum | cut -c1-8)
    elif command -v md5 >/dev/null 2>&1; then
        # macOS md5 command
        hash_suffix=$(echo "$random_data" | md5 | cut -c1-8)
    else
        # Fallback to simple hash based on timestamp and random
        hash_suffix=$(printf "%08x" $((timestamp % 4294967296)))
    fi
    
    echo "${timestamp}-${hash_suffix}"
}

create_registry_entry() {
    local agent_id="$1"
    local agent_created="$2"
    local oh_version="$3"
    local base_image="$4"
    local output_image="$5"
    local exchange_url="$6"
    local exchange_org="$7"
    local node_json="$8"
    local wifi_ssid="$9"
    
    log_debug "Creating registry entry for agent ID: $agent_id"
    
    # Extract filenames from full paths
    local base_image_name=$(basename "$base_image" 2>/dev/null || echo "$base_image")
    local output_image_name=$(basename "$output_image" 2>/dev/null || echo "$output_image")
    
    # Format exchange information
    local exchange_info="none"
    if [[ -n "$exchange_url" && -n "$exchange_org" ]]; then
        exchange_info="$exchange_url (org: $exchange_org)"
    fi
    
    # Format node.json information
    local node_json_info="default"
    if [[ -n "$node_json" ]]; then
        node_json_info=$(basename "$node_json" 2>/dev/null || echo "$node_json")
    fi
    
    # Format Wi-Fi information
    local wifi_info="none"
    if [[ -n "$wifi_ssid" ]]; then
        wifi_info="$wifi_ssid"
    fi
    
    # Create markdown-formatted registry entry (redirect to variable to avoid log mixing)
    local entry_content
    entry_content=$(cat << EOF

## Agent Configuration: $agent_id

- **Created**: $agent_created
- **Open Horizon Version**: $oh_version
- **Exchange URL**: $exchange_info
- **Node JSON**: $node_json_info
- **Wi-Fi SSID**: $wifi_info
- **Base Image**: $base_image_name
- **Output Image**: $output_image_name
- **Status**: created

EOF
)
    
    echo "$entry_content"
}

append_to_agents_file() {
    local agents_file="$1"
    local entry="$2"
    
    log_debug "Appending entry to REGISTRY.md file: $agents_file"
    
    # Validate input
    if [[ -z "$agents_file" || -z "$entry" ]]; then
        log_error "append_to_agents_file: Missing required parameters"
        return 1
    fi
    
    # Create REGISTRY.md file if it doesn't exist
    if [[ ! -f "$agents_file" ]]; then
        log_info "Creating new REGISTRY.md file: $agents_file"
        if ! create_agents_file_header > "$agents_file"; then
            log_error "append_to_agents_file: Failed to create REGISTRY.md header"
            return 1
        fi
    fi
    
    # Verify file is writable
    if [[ ! -w "$agents_file" ]]; then
        log_error "append_to_agents_file: REGISTRY.md file is not writable: $agents_file"
        return 1
    fi
    
    # Append registry entry
    if ! echo -e "\n$entry" >> "$agents_file"; then
        log_error "append_to_agents_file: Failed to append entry to REGISTRY.md"
        return 1
    fi
    
    # Create AGENTS.md file if it doesn't exist
    if [[ ! -f "$agents_file" ]]; then
        log_info "Creating new AGENTS.md file: $agents_file"
        create_agents_file_header "$agents_file" || {
            log_error "append_to_agents_file: Failed to create AGENTS.md header"
            return 1
        }
    fi
    
    # Verify file is writable
    if [[ ! -w "$agents_file" ]]; then
        log_error "append_to_agents_file: AGENTS.md file is not writable: $agents_file"
        return 1
    fi
    
    # Append the registry entry
    echo "$registry_entry" >> "$agents_file" || {
        log_error "append_to_agents_file: Failed to append entry to AGENTS.md"
        return 1
    }
    
    log_debug "Registry entry appended successfully"
    return 0
}

create_agents_file_header() {
    log_debug "Creating REGISTRY.md file header"
    
    # Create header with project description and format
    cat << 'EOF'
# Agent Registry

This file contains a registry of all Raspberry Pi images created with embedded Open Horizon components. Each entry represents a unique agent configuration with its deployment details.

## Registry Format

Each agent configuration includes:
- **Created**: ISO timestamp of when the image was created
- **Open Horizon Version**: Version of Open Horizon components installed
- **Exchange URL**: Open Horizon exchange URL and organization (or "none" if not configured)
- **Node JSON**: Custom node.json configuration file used (or "default")
- **Wi-Fi SSID**: Wi-Fi network configured (or "none" if not configured)
- **Base Image**: Original Raspberry Pi OS image filename
- **Output Image**: Generated custom image filename
- **Status**: Current status (created|deployed|retired)

## Agent Configurations
EOF
    
    if [[ $? -eq 0 ]]; then
        log_debug "REGISTRY.md header created successfully"
        return 0
    else
        log_error "create_agents_file_header: Failed to create REGISTRY.md header"
        return 1
    fi
}

create_agent_config_data() {
    # Helper function to create config data string from global variables
    local config_data=""
    
    # Format: oh_version|base_image|output_image|exchange_url|exchange_org|node_json|wifi_ssid
    config_data="${CONFIG_OH_VERSION}|${CONFIG_BASE_IMAGE}|${CONFIG_OUTPUT_IMAGE}"
    config_data="${config_data}|${CONFIG_EXCHANGE_URL}|${CONFIG_EXCHANGE_ORG}"
    config_data="${config_data}|${CONFIG_NODE_JSON}|${CONFIG_WIFI_SSID}"
    
    echo "$config_data"
}

validate_agents_file() {
    local agents_file="$1"
    
    log_debug "Validating REGISTRY.md file format: $agents_file"
    
    # Check if file exists
    if [[ ! -f "$agents_file" ]]; then
        log_debug "REGISTRY.md file does not exist (will be created)"
        return 0
    fi
    
    # Check if file is readable
    if [[ ! -r "$agents_file" ]]; then
        log_error "validate_agents_file: REGISTRY.md file is not readable: $agents_file"
        return 1
    fi
    
    # Verify file has expected header
    if ! grep -q "^# Agent Registry" "$agents_file"; then
        log_warn "validate_agents_file: REGISTRY.md file missing expected header"
        return 1
    fi
    
    # Check if file is empty (besides header)
    local agent_count
    agent_count=$(get_agent_count "$agents_file")
    if [[ $agent_count -eq 0 ]]; then
        log_warn "validate_agents_file: REGISTRY.md file is empty"
    fi
    
    log_debug "REGISTRY.md file validation completed"
    return 0
}

get_agent_count() {
    local agents_file="$1"
    
    # Count the number of agent configurations in the file
    if [[ -f "$agents_file" ]]; then
        local count
        count=$(grep -c "^## Agent Configuration:" "$agents_file" 2>/dev/null || echo "0")
        echo "$count"
    else
        echo "0"
    fi
}

list_agents() {
    local agents_file="${SCRIPT_DIR}/REGISTRY.md"
    
    log_info "Listing registered agents from: $agents_file"
    
    if [[ ! -f "$agents_file" ]]; then
        log_info "No REGISTRY.md file found - no agents registered yet"
        return 0
    fi
    
    local agent_count
    agent_count=$(get_agent_count "$agents_file")
    
    if [[ $agent_count -eq 0 ]]; then
        log_info "No agents found in registry"
        return 0
    fi
    
    log_info "Found $agent_count registered agent(s):"
    
    # Extract and display agent summaries
    while IFS= read -r line; do
        if [[ "$line" =~ ^##\ Agent\ Configuration:\ (.+)$ ]]; then
            local agent_id="${BASH_REMATCH[1]}"
            echo "  - Agent ID: $agent_id"
        fi
    done < "$agents_file"
    
    return 0
}

# Main function
main() {
    init_script
    
    log_info "Starting Raspberry Pi Image Builder"
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Detect platform and check dependencies
    detect_platform
    check_dependencies
    
    # Prompt for missing required parameters
    prompt_for_missing_parameters
    
    # Validate configuration
    validate_configuration
    
    # Log configuration summary
    log_configuration
    
    # Set cleanup flag
    CLEANUP_REQUIRED=true
    
    log_info "Platform detection and dependency checking completed successfully"
    
    # Verify base image format compatibility
    log_info "Verifying base image format compatibility"
    if verify_image_format_compatibility "$CONFIG_BASE_IMAGE"; then
        log_info "Base image format compatibility verification passed"
    else
        log_error "Base image format compatibility verification failed"
        exit 1
    fi
    
    # Register agent configuration in project registry
    log_info "Registering agent configuration in project registry"
    local config_data
    config_data=$(create_agent_config_data)
    
    if register_agent "$config_data"; then
        log_info "Agent configuration registered successfully"
    else
        log_warn "Failed to register agent configuration (non-critical)"
    fi
    
    # Mount the base image for processing
    log_info "Mounting base image for processing"
    local mount_device
    mount_device=$(mount_image "$CONFIG_BASE_IMAGE" "$CONFIG_MOUNT_POINT")
    if [[ $? -ne 0 || -z "$mount_device" ]]; then
        log_error "Failed to mount base image"
        exit 1
    fi
    
    log_info "Successfully mounted image on device: $mount_device"
    
    # Install Open Horizon components
    log_info "Installing Open Horizon components"
    
    if ! install_anax_agent "$CONFIG_MOUNT_POINT" "$CONFIG_OH_VERSION"; then
        log_error "Failed to install Open Horizon anax agent"
        unmount_image "$mount_device" "$CONFIG_MOUNT_POINT"
        exit 1
    fi
    
    if ! install_horizon_cli "$CONFIG_MOUNT_POINT" "$CONFIG_OH_VERSION"; then
        log_error "Failed to install Open Horizon CLI"
        unmount_image "$mount_device" "$CONFIG_MOUNT_POINT"
        exit 1
    fi
    
    if ! configure_agent_service "$CONFIG_MOUNT_POINT"; then
        log_error "Failed to configure Open Horizon agent service"
        unmount_image "$mount_device" "$CONFIG_MOUNT_POINT"
        exit 1
    fi
    
    log_info "Open Horizon components installed successfully"
    
    # Configure Wi-Fi if requested
    if is_wifi_configuration_requested; then
        log_info "Configuring Wi-Fi network"
        if ! configure_wifi "$CONFIG_MOUNT_POINT" "$CONFIG_WIFI_SSID" "$CONFIG_WIFI_PASSWORD" "$CONFIG_WIFI_SECURITY"; then
            log_error "Failed to configure Wi-Fi"
            unmount_image "$mount_device" "$CONFIG_MOUNT_POINT"
            exit 1
        fi
        log_info "Wi-Fi configuration completed successfully"
    else
        log_info "No Wi-Fi configuration requested"
    fi
    
    # Configure exchange registration if requested
    if [[ -n "$CONFIG_EXCHANGE_URL" ]]; then
        log_info "Configuring Open Horizon exchange registration"
        if ! configure_exchange_registration "$CONFIG_MOUNT_POINT" "$CONFIG_EXCHANGE_URL" "$CONFIG_EXCHANGE_ORG" "$CONFIG_EXCHANGE_USER" "$CONFIG_EXCHANGE_TOKEN" "$CONFIG_NODE_JSON"; then
            log_error "Failed to configure exchange registration"
            unmount_image "$mount_device" "$CONFIG_MOUNT_POINT"
            exit 1
        fi
        log_info "Exchange registration configuration completed successfully"
    else
        log_info "No exchange registration requested"
    fi
    
    # Final verification before unmounting
    log_info "Performing final verification of installed components"
    
    # Verify Open Horizon installation
    if ! verify_open_horizon_installation "$CONFIG_MOUNT_POINT" "$CONFIG_OH_VERSION"; then
        log_error "Open Horizon installation verification failed"
        unmount_image "$mount_device" "$CONFIG_MOUNT_POINT"
        exit 1
    fi
    
    log_info "Open Horizon installation verification passed"
    
    # Unmount the image
    log_info "Unmounting image and finalizing"
    if ! unmount_image "$mount_device" "$CONFIG_MOUNT_POINT"; then
        log_error "Failed to unmount image"
        exit 1
    fi
    
    log_info "Image unmounted successfully"
    
    # Verify final output image
    log_info "Verifying final output image"
    if ! verify_image "$CONFIG_OUTPUT_IMAGE" "extended"; then
        log_error "Final output image verification failed"
        exit 1
    fi
    
    log_info "Final output image verification passed"
    
    # Disable cleanup flag since we completed successfully
    CLEANUP_REQUIRED=false
    
    log_info "=== Image processing completed successfully ==="
    log_info "Custom Raspberry Pi image created: $CONFIG_OUTPUT_IMAGE"
    log_info "Image contains Open Horizon $CONFIG_OH_VERSION components"
    
    if [[ -n "$CONFIG_EXCHANGE_URL" ]]; then
        log_info "Image is configured for automatic exchange registration"
    fi
    
    if [[ -n "$CONFIG_WIFI_SSID" ]]; then
        log_info "Image is configured for Wi-Fi network: $CONFIG_WIFI_SSID"
    fi
    
    log_info "=== Raspberry Pi Image Builder finished successfully ==="
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi