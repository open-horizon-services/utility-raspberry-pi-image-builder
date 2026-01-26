#!/bin/bash

# Platform Detection Utility
# Cross-platform utility for detecting platform and checking dependencies
# Supports Linux and macOS with extensible tool detection

set -euo pipefail

# Global variables
# SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DETECTED_PLATFORM=""
PLATFORM_TOOLS=()
LOG_FILE=""

# Initialize logging if not already set
init_logging() {
    if [[ -z "${LOG_FILE:-}" ]]; then
        LOG_FILE="${SCRIPT_DIR}/platform-detect.log"
        echo "=== Platform Detection Utility Started at $(date) ===" > "$LOG_FILE"
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

# Detect the current platform
# Usage: detect_platform
# Outputs: platform name (linux|macos) and sets DETECTED_PLATFORM
detect_platform() {
    log_debug "Detecting platform..."
    
    local platform=""
    local uname_output=$(uname -s)
    local uname_machine=$(uname -m)
    
    case "$uname_output" in
        Linux*)
            platform="linux"
            ;;
        Darwin*)
            platform="macos"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            platform="windows"
            ;;
        FreeBSD*)
            platform="freebsd"
            ;;
        OpenBSD*)
            platform="openbsd"
            ;;
        *)
            log_error "Unsupported platform: $uname_output"
            log_error "This utility supports: Linux, macOS, Windows (Cygwin/MinGW/MSYS), FreeBSD, OpenBSD"
            exit 1
            ;;
    esac
    
    DETECTED_PLATFORM="$platform"
    log_info "Detected platform: $DETECTED_PLATFORM ($uname_output $uname_machine)"
    
    # Set platform-specific tools
    select_platform_tools
    
    return 0
}

# Select platform-specific tools
# Usage: select_platform_tools
# Sets: PLATFORM_TOOLS array
select_platform_tools() {
    log_debug "Selecting platform-specific tools for $DETECTED_PLATFORM"
    
    case "$DETECTED_PLATFORM" in
        linux)
            PLATFORM_TOOLS=(
                "losetup"      # Loop device management
                "mount"        # Filesystem mounting
                "umount"       # Filesystem unmounting
                "kpartx"       # Partition mapping for loop devices
                "chroot"       # Change root environment
                "wget"         # Download utility
                "curl"         # HTTP client
                "fdisk"        # Disk partitioning utility
                "resize2fs"    # Ext2/3/4 filesystem resizer
                "e2fsck"       # Ext2/3/4 filesystem checker
                "parted"       # Partition editor
                "qemu-aarch64-static"  # ARM emulation
                "systemctl"    # Systemd manager
                "service"      # System V service manager
            )
            ;;
        macos)
            PLATFORM_TOOLS=(
                "hdiutil"      # Disk image utility
                "diskutil"     # Disk utility
                "wget"         # Download utility (via Homebrew)
                "curl"         # HTTP client (built-in)
                "ditto"        # File copying utility
                "brew"         # Homebrew package manager
            )
            ;;
        windows)
            PLATFORM_TOOLS=(
                "wget"         # Download utility
                "curl"         # HTTP client (built-in)
                "powershell"   # PowerShell
                "choco"        # Chocolatey package manager
            )
            ;;
        freebsd)
            PLATFORM_TOOLS=(
                "mdconfig"     # Memory disk configuration
                "mount"        # Filesystem mounting
                "umount"       # Filesystem unmounting
                "wget"         # Download utility
                "curl"         # HTTP client
                "fdisk"        # Disk partitioning utility
                "gpart"        # GEOM partition editor
            )
            ;;
        openbsd)
            PLATFORM_TOOLS=(
                "vnconfig"     # vnode configuration
                "mount"        # Filesystem mounting
                "umount"       # Filesystem unmounting
                "wget"         # Download utility
                "curl"         # HTTP client
                "fdisk"        # Disk partitioning utility
                "disklabel"     # Disk label utility
            )
            ;;
        *)
            log_error "Unknown platform for tool selection: $DETECTED_PLATFORM"
            exit 1
            ;;
    esac
    
    log_debug "Selected ${#PLATFORM_TOOLS[@]} tools for platform: ${DETECTED_PLATFORM}"
}

# Check platform dependencies
# Usage: check_dependencies [tool_categories...]
# tool_categories: all|core|optional|mounting|verification|networking
check_dependencies() {
    log_info "Checking platform dependencies..."
    
    if [[ -z "$DETECTED_PLATFORM" ]]; then
        log_error "Platform not detected. Run detect_platform() first."
        exit 1
    fi
    
    local check_categories="${1:-all}"
    local missing_tools=()
    local optional_missing=()
    local tools_to_check=()
    
    # Filter tools based on category
    case "$check_categories" in
        all)
            tools_to_check=("${PLATFORM_TOOLS[@]}")
            ;;
        core)
            tools_to_check=($(get_core_tools))
            ;;
        optional)
            tools_to_check=($(get_optional_tools))
            ;;
        mounting)
            tools_to_check=($(get_mounting_tools))
            ;;
        verification)
            tools_to_check=($(get_verification_tools))
            ;;
        networking)
            tools_to_check=($(get_networking_tools))
            ;;
        *)
            log_error "Unknown dependency category: $check_categories"
            log_error "Valid categories: all, core, optional, mounting, verification, networking"
            return 1
            ;;
    esac
    
    # Check each required tool
    for tool in "${tools_to_check[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            case "$tool" in
                # Critical tools that must be present
                losetup|mount|umount|hdiutil|diskutil|curl|chroot)
                    missing_tools+=("$tool")
                    ;;
                # Optional tools that are nice to have
                wget|kpartx|resize2fs|e2fsck|fdisk|parted|ditto|qemu-aarch64-static)
                    optional_missing+=("$tool")
                    ;;
                # Platform-specific critical tools
                systemctl|service)
                    if [[ "$DETECTED_PLATFORM" == "linux" ]]; then
                        missing_tools+=("$tool")
                    else
                        optional_missing+=("$tool")
                    fi
                    ;;
                # Tools that might need special handling
                brew)
                    if [[ "$DETECTED_PLATFORM" == "macos" ]]; then
                        optional_missing+=("$tool")
                    else
                        missing_tools+=("$tool")
                    fi
                    ;;
                *)
                    missing_tools+=("$tool")
                    ;;
            esac
        else
            log_debug "Found tool: $tool"
        fi
    done
    
    # Report missing critical tools
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools:"
        for tool in "${missing_tools[@]}"; do
            log_error "  - $tool"
        done
        
        # Provide platform-specific installation guidance
        provide_installation_guidance "${missing_tools[@]}"
        return 1
    fi
    
    # Report missing optional tools as warnings
    if [[ ${#optional_missing[@]} -gt 0 ]]; then
        log_warn "Missing optional tools (functionality may be limited):"
        for tool in "${optional_missing[@]}"; do
            log_warn "  - $tool"
        done
        provide_optional_installation_guidance "${optional_missing[@]}"
    fi
    
    # Check for special platform requirements
    check_platform_requirements
    
    log_info "Dependency check completed successfully"
    return 0
}

# Get core tools for the current platform
get_core_tools() {
    case "$DETECTED_PLATFORM" in
        linux)
            echo "losetup mount umount curl"
            ;;
        macos)
            echo "hdiutil diskutil curl"
            ;;
        windows)
            echo "curl powershell"
            ;;
        freebsd)
            echo "mdconfig mount umount curl"
            ;;
        openbsd)
            echo "vnconfig mount umount curl"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Get optional tools for the current platform
get_optional_tools() {
    case "$DETECTED_PLATFORM" in
        linux)
            echo "wget kpartx fdisk parted resize2fs e2fsck qemu-aarch64-static systemctl service"
            ;;
        macos)
            echo "wget ditto brew"
            ;;
        windows)
            echo "wget choco"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Get mounting tools for the current platform
get_mounting_tools() {
    case "$DETECTED_PLATFORM" in
        linux)
            echo "losetup mount umount kpartx"
            ;;
        macos)
            echo "hdiutil diskutil"
            ;;
        freebsd)
            echo "mdconfig mount umount"
            ;;
        openbsd)
            echo "vnconfig mount umount"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Get verification tools for the current platform
get_verification_tools() {
    case "$DETECTED_PLATFORM" in
        linux)
            echo "fdisk parted file dd"
            ;;
        macos)
            echo "file dd"
            ;;
        *)
            echo "file dd"
            ;;
    esac
}

# Get networking tools for the current platform
get_networking_tools() {
    case "$DETECTED_PLATFORM" in
        linux|macos|freebsd|openbsd|windows)
            echo "curl wget"
            ;;
        *)
            echo "curl"
            ;;
    esac
}

# Check platform-specific requirements
check_platform_requirements() {
    log_debug "Checking platform-specific requirements"
    
    case "$DETECTED_PLATFORM" in
        linux)
            check_linux_requirements
            ;;
        macos)
            check_macos_requirements
            ;;
        windows)
            check_windows_requirements
            ;;
        freebsd)
            check_freebsd_requirements
            ;;
        openbsd)
            check_openbsd_requirements
            ;;
    esac
}

# Check Linux-specific requirements
check_linux_requirements() {
    log_debug "Checking Linux-specific requirements"
    
    # Check for root/sudo access for mount operations
    if [[ $EUID -eq 0 ]]; then
        log_info "Running as root - mount operations will work"
        return 0
    fi
    
    # Check if user can sudo
    if sudo -n true 2>/dev/null; then
        log_info "User has passwordless sudo access - mount operations will work"
        return 0
    fi
    
    # Check if user can sudo with password
    if sudo -v 2>/dev/null; then
        log_info "User has sudo access - mount operations will work (may prompt for password)"
        return 0
    fi
    
    log_warn "This script requires root privileges or sudo access for mount operations"
    log_warn "Please run with sudo or ensure your user has sudo privileges"
    return 0
}

# Check macOS-specific requirements
check_macos_requirements() {
    log_debug "Checking macOS-specific requirements"
    
    # Check if running on macOS with proper permissions
    if [[ -d "/System" ]]; then
        log_info "macOS system directory structure detected"
    else
        log_warn "macOS system directory structure not found"
    fi
    
    # Check for Xcode Command Line Tools (required for some operations)
    if xcode-select -p >/dev/null 2>&1; then
        log_debug "Xcode Command Line Tools are installed"
    else
        log_warn "Xcode Command Line Tools not installed - some features may not work"
        log_warn "Install with: xcode-select --install"
    fi
}

# Check Windows-specific requirements
check_windows_requirements() {
    log_debug "Checking Windows-specific requirements"
    
    # Check for PowerShell
    if command -v powershell >/dev/null 2>&1; then
        log_debug "PowerShell is available"
    else
        log_error "PowerShell not found - required for Windows support"
        return 1
    fi
    
    # Check for Windows Subsystem for Linux (optional)
    if wsl.exe -l >/dev/null 2>&1; then
        log_info "Windows Subsystem for Linux is available"
    else
        log_debug "Windows Subsystem for Linux not found (optional)"
    fi
}

# Check FreeBSD-specific requirements
check_freebsd_requirements() {
    log_debug "Checking FreeBSD-specific requirements"
    
    # Check if running on FreeBSD
    if [[ $(uname -s) == "FreeBSD" ]]; then
        log_info "FreeBSD platform detected"
    else
        log_warn "Not running on FreeBSD - some features may not work"
    fi
}

# Check OpenBSD-specific requirements
check_openbsd_requirements() {
    log_debug "Checking OpenBSD-specific requirements"
    
    # Check if running on OpenBSD
    if [[ $(uname -s) == "OpenBSD" ]]; then
        log_info "OpenBSD platform detected"
    else
        log_warn "Not running on OpenBSD - some features may not work"
    fi
}

# Provide installation guidance for missing tools
provide_installation_guidance() {
    local missing_tools=("$@")
    
    log_error ""
    log_error "Installation guidance for $DETECTED_PLATFORM:"
    
    case "$DETECTED_PLATFORM" in
        linux)
            log_error "On Ubuntu/Debian:"
            log_error "  sudo apt-get update"
            
            for tool in "${missing_tools[@]}"; do
                case "$tool" in
                    losetup|mount|umount|chroot)
                        log_error "  sudo apt-get install util-linux"
                        ;;
                    kpartx)
                        log_error "  sudo apt-get install kpartx"
                        ;;
                    wget)
                        log_error "  sudo apt-get install wget"
                        ;;
                    curl)
                        log_error "  sudo apt-get install curl"
                        ;;
                    fdisk|parted)
                        log_error "  sudo apt-get install fdisk parted"
                        ;;
                    resize2fs|e2fsck)
                        log_error "  sudo apt-get install e2fsprogs"
                        ;;
                    qemu-aarch64-static)
                        log_error "  sudo apt-get install qemu-user-static"
                        ;;
                    systemctl|service)
                        log_error "  sudo apt-get install systemd"
                        ;;
                esac
            done
            
            log_error ""
            log_error "On RHEL/CentOS/Fedora:"
            log_error "  sudo yum install util-linux kpartx wget curl e2fsprogs systemd qemu-user-static"
            log_error "  # or: sudo dnf install util-linux kpartx wget curl e2fsprogs systemd qemu-user-static"
            ;;
        macos)
            log_error "On macOS:"
            log_error "  # Install Homebrew if not already installed:"
            log_error "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            log_error ""
            
            for tool in "${missing_tools[@]}"; do
                case "$tool" in
                    wget)
                        log_error "  brew install wget"
                        ;;
                    hdiutil|diskutil|curl)
                        log_error "  # $tool should be built-in to macOS"
                        ;;
                esac
            done
            ;;
        windows)
            log_error "On Windows:"
            log_error "  # Install Chocolatey if not already installed:"
            log_error "  Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
            log_error ""
            
            for tool in "${missing_tools[@]}"; do
                case "$tool" in
                    wget)
                        log_error "  choco install wget"
                        ;;
                    curl|powershell)
                        log_error "  # $tool should be built-in to Windows"
                        ;;
                esac
            done
            ;;
    esac
    
    log_error ""
}

# Provide optional installation guidance
provide_optional_installation_guidance() {
    local missing_tools=("$@")
    
    log_warn ""
    log_warn "Optional tool installation guidance for $DETECTED_PLATFORM:"
    
    case "$DETECTED_PLATFORM" in
        linux)
            for tool in "${missing_tools[@]}"; do
                case "$tool" in
                    wget)
                        log_warn "  sudo apt-get install wget  # or: sudo yum install wget"
                        ;;
                    kpartx)
                        log_warn "  sudo apt-get install kpartx  # for advanced partition handling"
                        ;;
                    resize2fs|e2fsck)
                        log_warn "  sudo apt-get install e2fsprogs  # for filesystem operations"
                        ;;
                    fdisk|parted)
                        log_warn "  sudo apt-get install fdisk parted  # for partition management"
                        ;;
                    qemu-aarch64-static)
                        log_warn "  sudo apt-get install qemu-user-static  # for ARM emulation"
                        ;;
                esac
            done
            ;;
        macos)
            for tool in "${missing_tools[@]}"; do
                case "$tool" in
                    wget)
                        log_warn "  brew install wget  # alternative to curl"
                        ;;
                    ditto)
                        log_warn "  # ditto should be built-in to macOS"
                        ;;
                    brew)
                        log_warn "  # Install Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
                        ;;
                esac
            done
            ;;
    esac
    
    log_warn ""
}

# Get platform information
get_platform_info() {
    detect_platform
    
    local info=""
    info+="Platform: $DETECTED_PLATFORM\n"
    info+="OS: $(uname -s)\n"
    info+="Architecture: $(uname -m)\n"
    info+="Kernel: $(uname -r)\n"
    info+="Hostname: $(hostname)\n"
    
    if [[ "$DETECTED_PLATFORM" == "linux" ]]; then
        if [[ -f /etc/os-release ]]; then
            info+="Distribution: $(grep '^PRETTY_NAME=' /etc/os-release | cut -d'"' -f2)\n"
        fi
    elif [[ "$DETECTED_PLATFORM" == "macos" ]]; then
        info+="macOS Version: $(sw_vers -productVersion)\n"
        info+="Build: $(sw_vers -buildVersion)\n"
    fi
    
    echo -e "$info"
}

# CLI interface
show_usage() {
    cat << EOF
Platform Detection Utility

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    detect                             Detect current platform
    check [category]                    Check dependencies (category: all|core|optional|mounting|verification|networking)
    info                               Show detailed platform information
    help                               Show this help message

OPTIONS:
    --debug                            Enable debug logging
    --log-file <path>                  Set custom log file path

EXAMPLES:
    $0 detect
    $0 check all
    $0 check core
    $0 info

EOF
}

main() {
    init_logging
    detect_platform  # Always detect platform first
    
    local command="${1:-help}"
    
    case "$command" in
        detect)
            echo "$DETECTED_PLATFORM"
            ;;
        check)
            check_dependencies "${2:-all}"
            ;;
        info)
            get_platform_info
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