#!/bin/bash

# Network Configuration Utility
# Cross-platform utility for configuring Wi-Fi and network interfaces on Raspberry Pi images
# Supports WPA2 and WPA3 security

set -euo pipefail

# Global variables
# SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DETECTED_PLATFORM=""
LOG_FILE=""

# Initialize logging if not already set
init_logging() {
    if [[ -z "${LOG_FILE:-}" ]]; then
        LOG_FILE="${SCRIPT_DIR}/network-config.log"
        echo "=== Network Configuration Utility Started at $(date) ===" > "$LOG_FILE"
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
            exit 1
            ;;
    esac
    
    log_debug "Detected platform: $DETECTED_PLATFORM"
}

# Chroot helper functions (minimal stubs for standalone use)
setup_chroot_environment() {
    if command -v setup_chroot_environment >/dev/null 2>&1 && [[ "$(type -t setup_chroot_environment)" == "function" ]]; then
        return 0
    fi
    
    source "${SCRIPT_DIR}/chroot-utils.sh" 2>/dev/null || {
        log_warn "chroot-utils.sh not found, chroot operations may fail"
        return 1
    }
}

chroot_exec() {
    if command -v chroot_exec >/dev/null 2>&1 && [[ "$(type -t chroot_exec)" == "function" ]]; then
        command chroot_exec "$@"
        return $?
    fi
    
    source "${SCRIPT_DIR}/chroot-utils.sh" 2>/dev/null || {
        log_error "chroot-utils.sh required but not found"
        return 1
    }
    chroot_exec "$@"
}

# Validate Wi-Fi configuration parameters
# Usage: validate_wifi_configuration <ssid> <password> <security>
# Returns: 0 if valid, 1 if invalid
validate_wifi_configuration() {
    local ssid="$1"
    local password="$2"
    local security="$3"
    
    log_debug "Validating Wi-Fi configuration parameters"
    
    if [[ -z "$ssid" ]]; then
        log_error "validate_wifi_configuration: SSID cannot be empty"
        return 1
    fi
    
    if [[ ${#ssid} -gt 32 ]]; then
        log_error "validate_wifi_configuration: SSID too long (${#ssid} bytes, maximum 32 bytes)"
        return 1
    fi
    
    if [[ -z "$password" ]]; then
        log_error "validate_wifi_configuration: Password cannot be empty"
        return 1
    fi
    
    case "$security" in
        WPA2|WPA3)
            if [[ ${#password} -lt 8 ]]; then
                log_error "validate_wifi_configuration: $security password too short (${#password} chars, minimum 8 chars)"
                return 1
            fi
            if [[ ${#password} -gt 63 ]]; then
                log_error "validate_wifi_configuration: $security password too long (${#password} chars, maximum 63 chars)"
                return 1
            fi
            ;;
        *)
            log_error "validate_wifi_configuration: Invalid security type: $security"
            return 1
            ;;
    esac
    
    if [[ "$ssid" =~ [[:cntrl:]] ]]; then
        log_error "validate_wifi_configuration: SSID contains invalid control characters"
        return 1
    fi
    
    log_debug "Wi-Fi configuration validation passed"
    return 0
}

# Configure Wi-Fi network on Raspberry Pi image
# Usage: configure_wifi <chroot_path> <ssid> <password> [security]
# Returns: 0 on success, 1 on failure
configure_wifi() {
    local chroot_path="$1"
    local ssid="$2"
    local password="$3"
    local security="${4:-WPA2}"
    
    log_info "Configuring Wi-Fi network: $ssid"
    log_debug "Chroot path: $chroot_path"
    log_debug "Security type: $security"
    
    if [[ -z "$chroot_path" || -z "$ssid" || -z "$password" ]]; then
        log_error "configure_wifi: Missing required parameters (chroot_path, ssid, password)"
        return 1
    fi
    
    if [[ ! -d "$chroot_path" ]]; then
        log_error "configure_wifi: Chroot path does not exist: $chroot_path"
        return 1
    fi
    
    case "$security" in
        WPA2|WPA3)
            log_debug "Using security type: $security"
            ;;
        *)
            log_error "configure_wifi: Invalid security type: $security (must be WPA2 or WPA3)"
            return 1
            ;;
    esac
    
    local wpa_config_dir="${chroot_path}/etc/wpa_supplicant"
    if [[ ! -d "$wpa_config_dir" ]]; then
        log_debug "Creating wpa_supplicant configuration directory: $wpa_config_dir"
        mkdir -p "$wpa_config_dir" || {
            log_error "configure_wifi: Failed to create wpa_supplicant config directory"
            return 1
        }
    fi
    
    local wpa_config_file="${wpa_config_dir}/wpa_supplicant.conf"
    log_info "Creating wpa_supplicant configuration file: $wpa_config_file"
    
    local wpa_config_content=""
    case "$security" in
        WPA2)
            wpa_config_content=$(cat << EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={
    ssid="$ssid"
    psk="$password"
    key_mgmt=WPA-PSK
    proto=RSN
    pairwise=CCMP
    auth_alg=OPEN
}
EOF
)
            ;;
        WPA3)
            wpa_config_content=$(cat << EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US

network={
    ssid="$ssid"
    psk="$password"
    key_mgmt=SAE
    proto=RSN
    pairwise=CCMP
    group=CCMP
    ieee80211w=2
}
EOF
)
            ;;
    esac
    
    echo "$wpa_config_content" > "$wpa_config_file" || {
        log_error "configure_wifi: Failed to write wpa_supplicant configuration file"
        return 1
    }
    
    chmod 600 "$wpa_config_file" || {
        log_error "configure_wifi: Failed to set permissions on wpa_supplicant.conf"
        return 1
    }
    
    log_debug "Created wpa_supplicant configuration with $security security"
    
    log_info "Configuring Wi-Fi interface and networking services"
    
    setup_chroot_environment "$chroot_path" || {
        log_error "configure_wifi: Failed to set up chroot environment"
        return 1
    }
    
    log_debug "Enabling wpa_supplicant service"
    chroot_exec "$chroot_path" "systemctl enable wpa_supplicant" || {
        log_warn "configure_wifi: Failed to enable wpa_supplicant service (may not be critical)"
    }
    
    log_debug "Enabling dhcpcd service for automatic IP configuration"
    chroot_exec "$chroot_path" "systemctl enable dhcpcd" || {
        log_warn "configure_wifi: Failed to enable dhcpcd service (may not be critical)"
    }
    
    local dhcpcd_config_file="${chroot_path}/etc/dhcpcd.conf"
    if [[ -f "$dhcpcd_config_file" ]]; then
        if ! grep -q "wpa_supplicant" "$dhcpcd_config_file" 2>/dev/null; then
            log_debug "Adding wpa_supplicant configuration to dhcpcd.conf"
            cat >> "$dhcpcd_config_file" << 'EOF'

interface wlan0
env ifwireless=1
env wpa_supplicant_driver=nl80211,wext
EOF
        fi
    else
        log_warn "configure_wifi: dhcpcd.conf not found, creating basic configuration"
        cat > "$dhcpcd_config_file" << 'EOF'
hostname
clientid
persistent
option rapid_commit
option domain_name_servers, domain_name, domain_search, host_name
option classless_static_routes
option interface_mtu
require dhcp_server_identifier
slaac private

interface wlan0
env ifwireless=1
env wpa_supplicant_driver=nl80211,wext
EOF
    fi
    
    log_debug "Enabling SSH service for remote access"
    chroot_exec "$chroot_path" "systemctl enable ssh" || {
        log_warn "configure_wifi: Failed to enable SSH service (may not be critical)"
    }
    
    local boot_ssh_file="${chroot_path}/boot/ssh"
    touch "$boot_ssh_file" 2>/dev/null || {
        log_warn "configure_wifi: Failed to create SSH enable file (may not be critical)"
    }
    
    if [[ -f "$wpa_config_file" ]]; then
        local config_size
        config_size=$(stat -c%s "$wpa_config_file" 2>/dev/null || stat -f%z "$wpa_config_file" 2>/dev/null)
        if [[ $config_size -gt 0 ]]; then
            log_info "Wi-Fi configuration completed successfully"
            log_info "Network: $ssid (Security: $security)"
            return 0
        else
            log_error "configure_wifi: Configuration file is empty"
            return 1
        fi
    else
        log_error "configure_wifi: Configuration file was not created"
        return 1
    fi
}

# Configure Ethernet as network fallback
# Usage: configure_network_fallback <chroot_path>
# Returns: 0 on success, 1 on failure
configure_network_fallback() {
    local chroot_path="$1"
    
    log_info "Configuring network fallback to Ethernet"
    log_debug "Chroot path: $chroot_path"
    
    if [[ -z "$chroot_path" ]]; then
        log_error "configure_network_fallback: Missing chroot_path parameter"
        return 1
    fi
    
    if [[ ! -d "$chroot_path" ]]; then
        log_error "configure_network_fallback: Chroot path does not exist: $chroot_path"
        return 1
    fi
    
    local dhcpcd_config_file="${chroot_path}/etc/dhcpcd.conf"
    if [[ -f "$dhcpcd_config_file" ]]; then
        if ! grep -q "interface eth0" "$dhcpcd_config_file" 2>/dev/null; then
            log_debug "Adding Ethernet fallback configuration to dhcpcd.conf"
            cat >> "$dhcpcd_config_file" << 'EOF'

interface eth0
static ip_address=
profile static_eth0
static ip_address=
fallback
EOF
        fi
    fi
    
    log_info "Network fallback configuration completed"
    return 0
}

# Show usage information
show_usage() {
    cat << EOF
USAGE: $(basename "$0") <command> [options]

Network configuration utility for Raspberry Pi images.

COMMANDS:
    wifi <chroot_path> <ssid> <password> [security]
                                  Configure Wi-Fi (security: WPA2 or WPA3, default: WPA2)
    validate <ssid> <password> <security>
                                  Validate Wi-Fi parameters
    fallback <chroot_path>        Configure Ethernet fallback
    help                          Show this help message

EXAMPLES:
    # Configure Wi-Fi with WPA2
    $(basename "$0") wifi /mnt/rpi "MyNetwork" "MyPassword"

    # Configure Wi-Fi with WPA3
    $(basename "$0") wifi /mnt/rpi "MyNetwork" "MyPassword" WPA3

    # Validate Wi-Fi parameters
    $(basename "$0") validate "MyNetwork" "MyPassword" WPA2

    # Configure Ethernet fallback
    $(basename "$0") fallback /mnt/rpi

ENVIRONMENT:
    DEBUG=1                       Enable debug logging

DEPENDENCIES:
    - chroot-utils.sh for chroot operations
    - Raspberry Pi OS image mounted at chroot_path

NOTES:
    - SSID: Maximum 32 bytes
    - Password: 8-63 characters for WPA2/WPA3
    - Requires sudo privileges for chroot operations
    - Creates /etc/wpa_supplicant/wpa_supplicant.conf (chmod 600)
    - Enables SSH service for remote access

EOF
}

# Main CLI interface
main() {
    local command="${1:-}"
    
    init_logging
    detect_platform
    
    case "$command" in
        wifi)
            if [[ $# -lt 4 ]]; then
                log_error "Missing parameters for wifi command"
                show_usage
                exit 1
            fi
            configure_wifi "$2" "$3" "$4" "${5:-WPA2}"
            ;;
        validate)
            if [[ $# -lt 4 ]]; then
                log_error "Missing parameters for validate command"
                show_usage
                exit 1
            fi
            validate_wifi_configuration "$2" "$3" "$4"
            ;;
        fallback)
            if [[ $# -lt 2 ]]; then
                log_error "Missing chroot_path parameter"
                show_usage
                exit 1
            fi
            configure_network_fallback "$2"
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
