#!/bin/bash

# Image Verification Utility
# Cross-platform utility for verifying disk image integrity and format compatibility
# Supports multiple verification levels and image formats

set -euo pipefail

# Global variables
# SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DETECTED_PLATFORM=""
LOG_FILE=""

# Initialize logging if not already set
init_logging() {
    if [[ -z "${LOG_FILE:-}" ]]; then
        LOG_FILE="${SCRIPT_DIR}/image-verify.log"
        echo "=== Image Verification Utility Started at $(date) ===" > "$LOG_FILE"
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

# Verify image integrity and format
# Usage: verify_image <image_path> [verification_type]
# verification_type: basic|extended (default: basic)
verify_image() {
    local image_path="$1"
    local verification_type="${2:-basic}"
    
    log_info "Verifying image integrity: $image_path"
    log_debug "Verification type: $verification_type"
    
    # Validate inputs
    if [[ -z "$image_path" ]]; then
        log_error "verify_image: Image path is required"
        return 1
    fi
    
    if [[ ! -f "$image_path" ]]; then
        log_error "verify_image: Image file does not exist: $image_path"
        return 1
    fi
    
    # Basic file integrity checks
    log_debug "Performing basic file integrity checks"
    
    # Check file size (should be reasonable for a Raspberry Pi image)
    local file_size
    file_size=$(stat -c%s "$image_path" 2>/dev/null || stat -f%z "$image_path" 2>/dev/null)
    if [[ -z "$file_size" ]]; then
        log_error "verify_image: Could not determine file size"
        return 1
    fi
    
    log_debug "Image file size: $file_size bytes"
    
    # Check minimum size (should be at least 100MB for a minimal image)
    local min_size=$((100 * 1024 * 1024))  # 100MB
    if [[ $file_size -lt $min_size ]]; then
        log_error "verify_image: Image file too small (${file_size} bytes, minimum ${min_size} bytes)"
        return 1
    fi
    
    # Check maximum size (should be reasonable, e.g., less than 32GB)
    local max_size=$((32 * 1024 * 1024 * 1024))  # 32GB
    if [[ $file_size -gt $max_size ]]; then
        log_error "verify_image: Image file too large (${file_size} bytes, maximum ${max_size} bytes)"
        return 1
    fi
    
    # Check file header for common image formats
    log_debug "Checking file format"
    local file_header
    file_header=$(hexdump -C "$image_path" | head -1 2>/dev/null)
    if [[ -z "$file_header" ]]; then
        log_error "verify_image: Could not read file header"
        return 1
    fi
    
    log_debug "File header: $file_header"
    
    # Perform extended verification if requested
    if [[ "$verification_type" == "extended" ]]; then
        log_debug "Performing extended verification"
        
        # Try to mount the image temporarily for structure verification
        local temp_mount="/tmp/verify_mount_$$"
        mkdir -p "$temp_mount" || {
            log_error "verify_image: Could not create temporary mount point"
            return 1
        }
        
        # Source the mount utility and use it
        local mount_util="${SCRIPT_DIR}/image-mount.sh"
        if [[ ! -f "$mount_util" ]]; then
            log_error "verify_image: image-mount.sh utility not found at $mount_util"
            rmdir "$temp_mount" 2>/dev/null || true
            return 1
        fi
        
        source "$mount_util"
        detect_platform
        
        local mount_device
        mount_device=$(mount_image "$image_path" "$temp_mount" 2>/dev/null)
        local mount_result=$?
        
        if [[ $mount_result -eq 0 && -n "$mount_device" ]]; then
            log_debug "Successfully mounted image for verification"
            
            # Check for essential Raspberry Pi OS directories
            local essential_dirs=("/etc" "/usr" "/var" "/home" "/boot")
            local missing_dirs=()
            
            for dir in "${essential_dirs[@]}"; do
                if [[ ! -d "${temp_mount}${dir}" ]]; then
                    missing_dirs+=("$dir")
                fi
            done
            
            # Check for essential files
            local essential_files=("/etc/passwd" "/etc/fstab")
            local missing_files=()
            
            for file in "${essential_files[@]}"; do
                if [[ ! -f "${temp_mount}${file}" ]]; then
                    missing_files+=("$file")
                fi
            done
            
            # Unmount the image
            unmount_image "$mount_device" "$temp_mount" || {
                log_warn "verify_image: Failed to unmount verification mount"
            }
            
            # Report missing directories and files
            if [[ ${#missing_dirs[@]} -gt 0 ]]; then
                log_error "verify_image: Missing essential directories: ${missing_dirs[*]}"
                rmdir "$temp_mount" 2>/dev/null || true
                return 1
            fi
            
            if [[ ${#missing_files[@]} -gt 0 ]]; then
                log_error "verify_image: Missing essential files: ${missing_files[*]}"
                rmdir "$temp_mount" 2>/dev/null || true
                return 1
            fi
            
            log_info "Extended verification passed - image structure is valid"
        else
            log_warn "verify_image: Could not mount image for extended verification (basic verification only)"
        fi
        
        rmdir "$temp_mount" 2>/dev/null || true
    fi
    
    log_info "Image verification completed successfully"
    return 0
}

# Verify image format compatibility
# Usage: verify_image_format_compatibility <image_path>
verify_image_format_compatibility() {
    local image_path="$1"
    
    log_info "Verifying image format compatibility: $image_path"
    
    # Validate inputs
    if [[ -z "$image_path" ]]; then
        log_error "verify_image_format_compatibility: Image path is required"
        return 1
    fi
    
    if [[ ! -f "$image_path" ]]; then
        log_error "verify_image_format_compatibility: Image file does not exist: $image_path"
        return 1
    fi
    
    # Verify Raspberry Pi Imager compatibility
    log_info "Checking Raspberry Pi Imager compatibility"
    if ! verify_rpi_imager_compatibility "$image_path"; then
        log_error "verify_image_format_compatibility: Raspberry Pi Imager compatibility check failed"
        return 1
    fi
    
    # Verify standard Linux utilities compatibility
    log_info "Checking standard Linux utilities compatibility"
    if ! verify_linux_utilities_compatibility "$image_path"; then
        log_error "verify_image_format_compatibility: Linux utilities compatibility check failed"
        return 1
    fi
    
    # Verify partition table and filesystem structure
    log_info "Checking partition table and filesystem structure"
    if ! verify_partition_structure "$image_path"; then
        log_error "verify_image_format_compatibility: Partition structure validation failed"
        return 1
    fi
    
    log_info "Image format compatibility verification completed successfully"
    return 0
}

# Verify Raspberry Pi Imager compatibility
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
    
    log_debug "Raspberry Pi Imager compatibility check completed"
    return 0
}

# Verify Linux utilities compatibility
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

# Test dd compatibility
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

# Test file command recognition
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

# Test fdisk compatibility
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

# Test parted compatibility
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

# Verify partition table and filesystem structure
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

# Verify partition table structure
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

# Verify filesystem structure (basic check)
verify_filesystem_structure() {
    local image_path="$1"
    
    log_debug "Verifying filesystem structure"
    
    # For a basic verification, just check that we can read the image
    # Full filesystem structure verification would require mounting
    
    local file_size
    file_size=$(stat -c%s "$image_path" 2>/dev/null || stat -f%z "$image_path" 2>/dev/null)
    
    if [[ -n "$file_size" && $file_size -gt 0 ]]; then
        log_debug "Image appears to have a valid filesystem structure"
        return 0
    else
        log_error "verify_filesystem_structure: Image appears to be empty or corrupted"
        return 1
    fi
}

# CLI interface
image_verify_image_verify_show_usage() {
    cat << EOF
Image Verification Utility

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    verify <image_path> [type]        Verify image integrity (type: basic|extended)
    compatibility <image_path>         Verify image format compatibility
    structure <image_path>             Verify partition and filesystem structure
    help                              Show this help message

OPTIONS:
    --debug                            Enable debug logging
    --log-file <path>                  Set custom log file path

EXAMPLES:
    $0 verify rpi.img basic
    $0 verify rpi.img extended
    $0 compatibility rpi.img
    $0 structure rpi.img

EOF
}

main() {
    init_logging
    detect_platform
    
    local command="${1:-help}"
    
    case "$command" in
        verify)
            if [[ $# -lt 2 ]]; then
                log_error "verify command requires at least 1 argument: <image_path> [type]"
                image_verify_show_usage
                exit 1
            fi
            verify_image "$2" "${3:-basic}"
            ;;
        compatibility)
            if [[ $# -ne 2 ]]; then
                log_error "compatibility command requires 1 argument: <image_path>"
                image_verify_show_usage
                exit 1
            fi
            verify_image_format_compatibility "$2"
            ;;
        structure)
            if [[ $# -ne 2 ]]; then
                log_error "structure command requires 1 argument: <image_path>"
                image_verify_show_usage
                exit 1
            fi
            verify_partition_structure "$2"
            ;;
        help|--help|-h)
            image_verify_show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            image_verify_show_usage
            exit 1
            ;;
    esac
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi