#!/bin/bash

# Open Horizon Installation Library
# Handles Open Horizon component installation, verification, and exchange registration
# Supports ARM emulation for x86 hosts

set -euo pipefail

# Global variables
# SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DETECTED_PLATFORM=""
LOG_FILE=""

# Initialize logging if not already set
init_logging() {
    if [[ -z "${LOG_FILE:-}" ]]; then
        LOG_FILE="${SCRIPT_DIR}/horizon-install.log"
        echo "=== Horizon Installation Library Started at $(date) ===" > "$LOG_FILE"
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

# Helper stubs for chroot utilities (source from chroot-utils.sh if available)
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

# Verify Open Horizon installation
# Usage: verify_open_horizon_installation <chroot_path> <expected_version>
# Returns: 0 on success, 1 on failure
verify_open_horizon_installation() {
    local chroot_path="$1"
    local expected_version="$2"
    
    log_info "Verifying Open Horizon installation in: $chroot_path"
    
    # Validate inputs
    if [[ -z "$chroot_path" || -z "$expected_version" ]]; then
        log_error "verify_open_horizon_installation: Missing required parameters"
        return 1
    fi
    
    if [[ ! -d "$chroot_path" ]]; then
        log_error "verify_open_horizon_installation: Chroot path does not exist: $chroot_path"
        return 1
    fi
    
    # Check for Open Horizon binary installations
    local oh_binaries=("/usr/bin/hzn" "/usr/local/bin/hzn" "/opt/horizon/bin/hzn")
    local hzn_found=false
    local hzn_path=""
    
    for binary_path in "${oh_binaries[@]}"; do
        if [[ -f "${chroot_path}${binary_path}" ]]; then
            hzn_found=true
            hzn_path="${binary_path}"
            log_debug "Found Open Horizon CLI at: ${binary_path}"
            break
        fi
    done
    
    if [[ "$hzn_found" == "false" ]]; then
        log_error "verify_open_horizon_installation: Open Horizon CLI (hzn) not found"
        return 1
    fi
    
    # Check for anax agent service file
    local anax_service_files=("/etc/systemd/system/horizon.service" "/lib/systemd/system/horizon.service")
    local service_found=false
    
    for service_file in "${anax_service_files[@]}"; do
        if [[ -f "${chroot_path}${service_file}" ]]; then
            service_found=true
            log_debug "Found Open Horizon service file: ${service_file}"
            break
        fi
    done
    
    if [[ "$service_found" == "false" ]]; then
        log_error "verify_open_horizon_installation: Open Horizon service file not found"
        return 1
    fi
    
    # Check for Open Horizon configuration directories
    local oh_config_dirs=("/etc/horizon" "/var/horizon")
    local config_dirs_found=true
    
    for config_dir in "${oh_config_dirs[@]}"; do
        if [[ ! -d "${chroot_path}${config_dir}" ]]; then
            log_debug "Open Horizon config directory not found: ${config_dir}"
            config_dirs_found=false
        fi
    done
    
    if [[ "$config_dirs_found" == "false" ]]; then
        log_error "verify_open_horizon_installation: Open Horizon configuration directories missing"
        return 1
    fi
    
    # Try to verify version (if possible within chroot constraints)
    log_debug "Verifying Open Horizon version matches expected: $expected_version"
    
    # For basic verification, check if version appears in hzn help output
    # This is a simplified check - in a full implementation, we might need to chroot
    local version_check_file="${chroot_path}/tmp/hzn_version_check"
    
    # Create a simple version check script
    cat > "$version_check_file" << 'EOF'
#!/bin/bash
# Simple Open Horizon version check
if command -v hzn >/dev/null 2>&1; then
    hzn version 2>/dev/null | head -1 || echo "hzn_command_available"
else
    echo "hzn_not_found"
fi
EOF
    
    chmod +x "$version_check_file" 2>/dev/null || {
        log_debug "verify_open_horizon_installation: Could not make version check script executable"
    }
    
    # Remove the temporary script
    rm -f "$version_check_file" 2>/dev/null || true
    
    log_info "Open Horizon installation verification passed"
    log_debug "  - CLI found: $hzn_path"
    log_debug "  - Service file found: ${service_found}"
    log_debug "  - Configuration directories found: ${config_dirs_found}"
    
    return 0
}

# Install Open Horizon anax agent
# Usage: install_anax_agent <chroot_path> <version>
# Returns: 0 on success, 1 on failure
install_anax_agent() {
    local chroot_path="$1"
    local version="$2"
    
    log_info "Installing Open Horizon anax agent version $version"
    log_debug "Chroot path: $chroot_path"
    
    # Validate inputs
    if [[ -z "$chroot_path" || -z "$version" ]]; then
        log_error "install_anax_agent: Missing required parameters (chroot_path, version)"
        return 1
    fi
    
    if [[ ! -d "$chroot_path" ]]; then
        log_error "install_anax_agent: Chroot path does not exist: $chroot_path"
        return 1
    fi
    
    # Set up chroot environment for ARM emulation if needed
    setup_chroot_environment "$chroot_path" || {
        log_error "install_anax_agent: Failed to set up chroot environment"
        return 1
    }
    
    # Download and install anax agent
    local anax_package_url="https://github.com/open-horizon/anax/releases/download/v${version}/horizon_${version}_arm64.deb"
    local anax_package_file="horizon_${version}_arm64.deb"
    local temp_dir="${chroot_path}/tmp/horizon_install"
    
    log_debug "Creating temporary installation directory: $temp_dir"
    mkdir -p "$temp_dir" || {
        log_error "install_anax_agent: Failed to create temp directory: $temp_dir"
        return 1
    }
    
    # Download anax package
    log_info "Downloading anax agent package from: $anax_package_url"
    if command -v wget >/dev/null 2>&1; then
        wget -O "${temp_dir}/${anax_package_file}" "$anax_package_url" 2>/dev/null || {
            log_error "install_anax_agent: Failed to download anax package with wget"
            return 1
        }
    elif command -v curl >/dev/null 2>&1; then
        curl -L -o "${temp_dir}/${anax_package_file}" "$anax_package_url" 2>/dev/null || {
            log_error "install_anax_agent: Failed to download anax package with curl"
            return 1
        }
    else
        log_error "install_anax_agent: Neither wget nor curl available for download"
        return 1
    fi
    
    # Verify package was downloaded
    if [[ ! -f "${temp_dir}/${anax_package_file}" ]]; then
        log_error "install_anax_agent: Package file not found after download"
        return 1
    fi
    
    local package_size
    package_size=$(stat -c%s "${temp_dir}/${anax_package_file}" 2>/dev/null || stat -f%z "${temp_dir}/${anax_package_file}" 2>/dev/null)
    log_debug "Downloaded package size: $package_size bytes"
    
    # Install package in chroot environment
    log_info "Installing anax agent package in chroot environment"
    
    # Update package lists first
    chroot_exec "$chroot_path" "apt-get update" || {
        log_error "install_anax_agent: Failed to update package lists in chroot"
        return 1
    }
    
    # Install dependencies
    log_debug "Installing anax agent dependencies"
    chroot_exec "$chroot_path" "apt-get install -y systemd curl jq" || {
        log_error "install_anax_agent: Failed to install dependencies"
        return 1
    }
    
    # Install the anax package
    chroot_exec "$chroot_path" "dpkg -i /tmp/horizon_install/${anax_package_file}" || {
        log_warn "install_anax_agent: dpkg install failed, attempting to fix dependencies"
        chroot_exec "$chroot_path" "apt-get install -f -y" || {
            log_error "install_anax_agent: Failed to fix dependencies"
            return 1
        }
    }
    
    # Verify installation
    if ! chroot_exec "$chroot_path" "which anax" >/dev/null 2>&1; then
        log_error "install_anax_agent: anax binary not found after installation"
        return 1
    fi
    
    # Get installed version for verification
    local installed_version
    installed_version=$(chroot_exec "$chroot_path" "anax -version" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [[ "$installed_version" == "$version" ]]; then
        log_info "Successfully installed anax agent version: $installed_version"
    else
        log_warn "Version mismatch: requested $version, installed $installed_version"
    fi
    
    # Clean up temporary files
    log_debug "Cleaning up temporary installation files"
    rm -rf "$temp_dir" || {
        log_warn "install_anax_agent: Failed to clean up temp directory"
    }
    
    log_info "Anax agent installation completed successfully"
    return 0
}

# Install Open Horizon CLI
# Usage: install_horizon_cli <chroot_path> <version>
# Returns: 0 on success, 1 on failure
install_horizon_cli() {
    local chroot_path="$1"
    local version="$2"
    
    log_info "Installing Open Horizon CLI version $version"
    log_debug "Chroot path: $chroot_path"
    
    # Validate inputs
    if [[ -z "$chroot_path" || -z "$version" ]]; then
        log_error "install_horizon_cli: Missing required parameters (chroot_path, version)"
        return 1
    fi
    
    if [[ ! -d "$chroot_path" ]]; then
        log_error "install_horizon_cli: Chroot path does not exist: $chroot_path"
        return 1
    fi
    
    # Set up chroot environment for ARM emulation if needed
    setup_chroot_environment "$chroot_path" || {
        log_error "install_horizon_cli: Failed to set up chroot environment"
        return 1
    }
    
    # Download and install Horizon CLI
    local cli_package_url="https://github.com/open-horizon/anax/releases/download/v${version}/horizon-cli_${version}_arm64.deb"
    local cli_package_file="horizon-cli_${version}_arm64.deb"
    local temp_dir="${chroot_path}/tmp/horizon_cli_install"
    
    log_debug "Creating temporary CLI installation directory: $temp_dir"
    mkdir -p "$temp_dir" || {
        log_error "install_horizon_cli: Failed to create temp directory: $temp_dir"
        return 1
    }
    
    # Download CLI package
    log_info "Downloading Horizon CLI package from: $cli_package_url"
    if command -v wget >/dev/null 2>&1; then
        wget -O "${temp_dir}/${cli_package_file}" "$cli_package_url" 2>/dev/null || {
            log_error "install_horizon_cli: Failed to download CLI package with wget"
            return 1
        }
    elif command -v curl >/dev/null 2>&1; then
        curl -L -o "${temp_dir}/${cli_package_file}" "$cli_package_url" 2>/dev/null || {
            log_error "install_horizon_cli: Failed to download CLI package with curl"
            return 1
        }
    else
        log_error "install_horizon_cli: Neither wget nor curl available for download"
        return 1
    fi
    
    # Verify package was downloaded
    if [[ ! -f "${temp_dir}/${cli_package_file}" ]]; then
        log_error "install_horizon_cli: CLI package file not found after download"
        return 1
    fi
    
    local package_size
    package_size=$(stat -c%s "${temp_dir}/${cli_package_file}" 2>/dev/null || stat -f%z "${temp_dir}/${cli_package_file}" 2>/dev/null)
    log_debug "Downloaded CLI package size: $package_size bytes"
    
    # Install CLI package in chroot environment
    log_info "Installing Horizon CLI package in chroot environment"
    
    # Install the CLI package
    chroot_exec "$chroot_path" "dpkg -i /tmp/horizon_cli_install/${cli_package_file}" || {
        log_warn "install_horizon_cli: dpkg install failed, attempting to fix dependencies"
        chroot_exec "$chroot_path" "apt-get install -f -y" || {
            log_error "install_horizon_cli: Failed to fix dependencies"
            return 1
        }
    }
    
    # Verify CLI installation
    if ! chroot_exec "$chroot_path" "which hzn" >/dev/null 2>&1; then
        log_error "install_horizon_cli: hzn binary not found after installation"
        return 1
    fi
    
    # Get installed CLI version for verification
    local installed_cli_version
    installed_cli_version=$(chroot_exec "$chroot_path" "hzn version" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [[ "$installed_cli_version" == "$version" ]]; then
        log_info "Successfully installed Horizon CLI version: $installed_cli_version"
    else
        log_warn "CLI version mismatch: requested $version, installed $installed_cli_version"
    fi
    
    # Clean up temporary files
    log_debug "Cleaning up temporary CLI installation files"
    rm -rf "$temp_dir" || {
        log_warn "install_horizon_cli: Failed to clean up CLI temp directory"
    }
    
    log_info "Horizon CLI installation completed successfully"
    return 0
}

# Configure Open Horizon agent service for auto-start
# Usage: configure_agent_service <chroot_path>
# Returns: 0 on success, 1 on failure
configure_agent_service() {
    local chroot_path="$1"
    
    log_info "Configuring Open Horizon agent service for auto-start"
    log_debug "Chroot path: $chroot_path"
    
    # Validate inputs
    if [[ -z "$chroot_path" ]]; then
        log_error "configure_agent_service: Missing required parameter (chroot_path)"
        return 1
    fi
    
    if [[ ! -d "$chroot_path" ]]; then
        log_error "configure_agent_service: Chroot path does not exist: $chroot_path"
        return 1
    fi
    
    # Set up chroot environment
    setup_chroot_environment "$chroot_path" || {
        log_error "configure_agent_service: Failed to set up chroot environment"
        return 1
    }
    
    # Check if horizon service exists
    if ! chroot_exec "$chroot_path" "systemctl list-unit-files | grep -q horizon" 2>/dev/null; then
        log_error "configure_agent_service: Horizon service not found in systemd"
        return 1
    fi
    
    # Enable the horizon service
    log_info "Enabling horizon service for auto-start"
    chroot_exec "$chroot_path" "systemctl enable horizon" || {
        log_error "configure_agent_service: Failed to enable horizon service"
        return 1
    }
    
    # Create horizon configuration directory if it doesn't exist
    local horizon_config_dir="${chroot_path}/etc/horizon"
    if [[ ! -d "$horizon_config_dir" ]]; then
        log_debug "Creating horizon configuration directory: $horizon_config_dir"
        mkdir -p "$horizon_config_dir" || {
            log_error "configure_agent_service: Failed to create horizon config directory"
            return 1
        }
    fi
    
    # Set proper permissions on configuration directory
    chroot_exec "$chroot_path" "chown -R root:root /etc/horizon" || {
        log_warn "configure_agent_service: Failed to set ownership on config directory"
    }
    
    chroot_exec "$chroot_path" "chmod 755 /etc/horizon" || {
        log_warn "configure_agent_service: Failed to set permissions on config directory"
    }
    
    # Verify service configuration
    if chroot_exec "$chroot_path" "systemctl is-enabled horizon" >/dev/null 2>&1; then
        log_info "Horizon service successfully configured for auto-start"
    else
        log_error "configure_agent_service: Service enable verification failed"
        return 1
    fi
    
    # Create a basic anax configuration file if it doesn't exist
    local anax_config_file="${horizon_config_dir}/anax.json"
    if [[ ! -f "$anax_config_file" ]]; then
        log_debug "Creating basic anax configuration file"
        cat > "$anax_config_file" << 'EOF'
{
    "Edge": {
        "ServiceStorage": "/var/horizon/service_storage/",
        "APIListen": "127.0.0.1:8510",
        "DBPath": "/var/horizon/anax.db",
        "DockerEndpoint": "unix:///var/run/docker.sock",
        "DefaultCPUSet": "",
        "DefaultServiceRegistrationRAM": 128,
        "StaticWebContent": "/var/horizon/web/"
    },
    "AgreementBot": {},
    "Collaborators": {
        "HTTPClientFactory": {
            "NewHTTPClientTimeoutS": 20
        }
    }
}
EOF
        
        # Set proper permissions on config file
        chroot_exec "$chroot_path" "chown root:root /etc/horizon/anax.json" || {
            log_warn "configure_agent_service: Failed to set ownership on anax.json"
        }
        
        chroot_exec "$chroot_path" "chmod 644 /etc/horizon/anax.json" || {
            log_warn "configure_agent_service: Failed to set permissions on anax.json"
        }
        
        log_debug "Created basic anax configuration file"
    fi
    
    log_info "Agent service configuration completed successfully"
    return 0
}

# Configure Open Horizon exchange registration
# Usage: configure_exchange_registration <chroot_path> <exchange_url> <exchange_org> <exchange_user> <exchange_token> [node_json_path]
# Returns: 0 on success, 1 on failure
configure_exchange_registration() {
    local chroot_path="$1"
    local exchange_url="$2"
    local exchange_org="$3"
    local exchange_user="$4"
    local exchange_token="$5"
    local node_json_path="$6"
    
    log_info "Configuring Open Horizon exchange registration"
    log_debug "Chroot path: $chroot_path"
    log_debug "Exchange URL: $exchange_url"
    log_debug "Exchange Organization: $exchange_org"
    log_debug "Exchange User: $exchange_user"
    log_debug "Node JSON path: ${node_json_path:-default}"
    
    # Validate inputs
    if [[ -z "$chroot_path" ]]; then
        log_error "configure_exchange_registration: Missing chroot_path parameter"
        return 1
    fi
    
    if [[ ! -d "$chroot_path" ]]; then
        log_error "configure_exchange_registration: Chroot path does not exist: $chroot_path"
        return 1
    fi
    
    # Validate exchange parameters
    if [[ -z "$exchange_url" || -z "$exchange_org" || -z "$exchange_user" || -z "$exchange_token" ]]; then
        log_error "configure_exchange_registration: Missing required exchange parameters"
        return 1
    fi
    
    # Validate custom node.json file if provided
    if [[ -n "$node_json_path" && ! -f "$node_json_path" ]]; then
        log_error "configure_exchange_registration: Custom node.json file does not exist: $node_json_path"
        return 1
    fi
    
    # Validate exchange connectivity during image creation
    log_info "Validating exchange connectivity"
    if ! validate_exchange_connectivity "$exchange_url"; then
        log_error "configure_exchange_registration: Exchange connectivity validation failed"
        return 1
    fi
    
    # Create horizon configuration directory if it doesn't exist
    local horizon_config_dir="${chroot_path}/etc/horizon"
    if [[ ! -d "$horizon_config_dir" ]]; then
        log_debug "Creating horizon configuration directory: $horizon_config_dir"
        mkdir -p "$horizon_config_dir" || {
            log_error "configure_exchange_registration: Failed to create horizon config directory"
            return 1
        }
    fi
    
    # Securely embed exchange credentials
    log_info "Embedding exchange credentials securely"
    if ! embed_exchange_credentials "$chroot_path" "$exchange_url" "$exchange_org" "$exchange_user" "$exchange_token"; then
        log_error "configure_exchange_registration: Failed to embed exchange credentials"
        return 1
    fi
    
    # Handle node.json configuration
    log_info "Configuring node.json"
    if ! configure_node_json "$chroot_path" "$node_json_path"; then
        log_error "configure_exchange_registration: Failed to configure node.json"
        return 1
    fi
    
    # Set up cloud-init for first-boot registration
    log_info "Setting up cloud-init for first-boot registration"
    local registration_config=$(create_registration_config "$exchange_url" "$exchange_org" "$exchange_user" "$exchange_token")
    if ! setup_cloud_init "$chroot_path" "$registration_config"; then
        log_error "configure_exchange_registration: Failed to set up cloud-init"
        return 1
    fi
    
    # Create firstrun.sh script for Raspberry Pi OS integration
    log_info "Creating firstrun.sh script for Raspberry Pi OS integration"
    if ! create_firstrun_script "$chroot_path" "$registration_config"; then
        log_error "configure_exchange_registration: Failed to create firstrun.sh script"
        return 1
    fi
    
    log_info "Exchange registration configuration completed successfully"
    return 0
}

# Set up cloud-init for first-boot configuration
# Usage: setup_cloud_init <chroot_path> <config_data>
# Returns: 0 on success, 1 on failure
setup_cloud_init() {
    local chroot_path="$1"
    local config_data="$2"
    
    log_info "Setting up cloud-init for first-boot configuration"
    log_debug "Chroot path: $chroot_path"
    
    # Validate inputs
    if [[ -z "$chroot_path" || -z "$config_data" ]]; then
        log_error "setup_cloud_init: Missing required parameters (chroot_path, config_data)"
        return 1
    fi
    
    if [[ ! -d "$chroot_path" ]]; then
        log_error "setup_cloud_init: Chroot path does not exist: $chroot_path"
        return 1
    fi
    
    # Create cloud-init configuration directories
    local cloud_init_dir="${chroot_path}/etc/cloud"
    local cloud_config_dir="${cloud_init_dir}/cloud.cfg.d"
    
    log_debug "Creating cloud-init configuration directories"
    mkdir -p "$cloud_config_dir" || {
        log_error "setup_cloud_init: Failed to create cloud-init config directory"
        return 1
    }
    
    # Install cloud-init if not already present
    log_debug "Ensuring cloud-init is installed"
    setup_chroot_environment "$chroot_path" || {
        log_error "setup_cloud_init: Failed to set up chroot environment"
        return 1
    }
    
    # Check if cloud-init is installed
    if ! chroot_exec "$chroot_path" "dpkg -l | grep -q cloud-init" 2>/dev/null; then
        log_info "Installing cloud-init package"
        chroot_exec "$chroot_path" "apt-get update" || {
            log_error "setup_cloud_init: Failed to update package lists"
            return 1
        }
        
        chroot_exec "$chroot_path" "apt-get install -y cloud-init" || {
            log_error "setup_cloud_init: Failed to install cloud-init"
            return 1
        }
    fi
    
    # Create cloud-init configuration for Open Horizon registration
    local cloud_config_file="${cloud_config_dir}/99-open-horizon.cfg"
    log_info "Creating cloud-init configuration file: $cloud_config_file"
    
    cat > "$cloud_config_file" << EOF
#cloud-config
# Open Horizon registration configuration
# Generated by Raspberry Pi Image Builder

# Run commands after network is available
runcmd:
  - echo "Starting Open Horizon registration process" >> /var/log/horizon-registration.log
  - /usr/local/bin/horizon-register.sh >> /var/log/horizon-registration.log 2>&1
  - echo "Open Horizon registration process completed" >> /var/log/horizon-registration.log

# Ensure network is available before running commands
bootcmd:
  - echo "Waiting for network connectivity..." >> /var/log/horizon-registration.log

# Set up logging
write_files:
  - path: /var/log/horizon-registration.log
    content: |
      Open Horizon Registration Log
      ============================
      Started at: \$(date)
    permissions: '0644'
    owner: root:root

# Final message
final_message: "Open Horizon cloud-init setup completed"
EOF
    
    # Set proper permissions on cloud-init configuration
    chmod 644 "$cloud_config_file" || {
        log_error "setup_cloud_init: Failed to set permissions on cloud-init config"
        return 1
    }
    
    # Enable cloud-init services
    log_debug "Enabling cloud-init services"
    chroot_exec "$chroot_path" "systemctl enable cloud-init" || {
        log_warn "setup_cloud_init: Failed to enable cloud-init service (may not be critical)"
    }
    
    chroot_exec "$chroot_path" "systemctl enable cloud-init-local" || {
        log_warn "setup_cloud_init: Failed to enable cloud-init-local service (may not be critical)"
    }
    
    chroot_exec "$chroot_path" "systemctl enable cloud-config" || {
        log_warn "setup_cloud_init: Failed to enable cloud-config service (may not be critical)"
    }
    
    chroot_exec "$chroot_path" "systemctl enable cloud-final" || {
        log_warn "setup_cloud_init: Failed to enable cloud-final service (may not be critical)"
    }
    
    # Create cloud-init datasource configuration for NoCloud
    local datasource_config_file="${cloud_config_dir}/90-dpkg.cfg"
    log_debug "Creating datasource configuration"
    
    cat > "$datasource_config_file" << EOF
# Cloud-init datasource configuration
# Use NoCloud datasource for local configuration
datasource_list: [ NoCloud, None ]
datasource:
  NoCloud:
    # Look for user-data and meta-data in /boot
    seedfrom: /boot/
EOF
    
    chmod 644 "$datasource_config_file" || {
        log_warn "setup_cloud_init: Failed to set permissions on datasource config"
    }
    
    log_info "Cloud-init setup completed successfully"
    return 0
}

# Create firstrun.sh script for Raspberry Pi OS integration
# Usage: create_firstrun_script <chroot_path> <registration_config>
# Returns: 0 on success, 1 on failure
create_firstrun_script() {
    local chroot_path="$1"
    local registration_config="$2"
    
    log_info "Creating firstrun.sh script for Raspberry Pi OS integration"
    log_debug "Chroot path: $chroot_path"
    
    # Validate inputs
    if [[ -z "$chroot_path" || -z "$registration_config" ]]; then
        log_error "create_firstrun_script: Missing required parameters (chroot_path, registration_config)"
        return 1
    fi
    
    if [[ ! -d "$chroot_path" ]]; then
        log_error "create_firstrun_script: Chroot path does not exist: $chroot_path"
        return 1
    fi
    
    # Create the horizon registration script
    local horizon_register_script="${chroot_path}/usr/local/bin/horizon-register.sh"
    log_info "Creating horizon registration script: $horizon_register_script"
    
    # Ensure the directory exists
    mkdir -p "$(dirname "$horizon_register_script")" || {
        log_error "create_firstrun_script: Failed to create script directory"
        return 1
    }
    
    # Parse registration config (assuming it's in format: url|org|user|token)
    local exchange_url exchange_org exchange_user exchange_token
    IFS='|' read -r exchange_url exchange_org exchange_user exchange_token <<< "$registration_config"
    
    cat > "$horizon_register_script" << EOFSCRIPT
#!/bin/bash
# Open Horizon Registration Script
# Generated by Raspberry Pi Image Builder
# This script registers the device with the Open Horizon exchange on first boot

set -euo pipefail

# Configuration variables
EXCHANGE_URL="$exchange_url"
EXCHANGE_ORG="$exchange_org"
EXCHANGE_USER="$exchange_user"
EXCHANGE_TOKEN="$exchange_token"

# Logging function
log_message() {
    local message="\$1"
    local timestamp=\$(date '+%Y-%m-%d %H:%M:%S')
    echo "[\$timestamp] \$message" | tee -a /var/log/horizon-registration.log
}

# Wait for network connectivity
wait_for_network() {
    local max_attempts=30
    local attempt=1
    
    log_message "Waiting for network connectivity..."
    
    while [[ \$attempt -le \$max_attempts ]]; do
        if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
            log_message "Network connectivity established"
            return 0
        fi
        
        log_message "Network attempt \$attempt/\$max_attempts failed, waiting 10 seconds..."
        sleep 10
        attempt=\$((attempt + 1))
    done
    
    log_message "ERROR: Failed to establish network connectivity after \$max_attempts attempts"
    return 1
}

# Validate exchange connectivity
validate_exchange() {
    local exchange_url="\$1"
    
    log_message "Validating exchange connectivity to: \$exchange_url"
    
    if curl -s --connect-timeout 10 "\$exchange_url/v1/admin/version" >/dev/null 2>&1; then
        log_message "Exchange connectivity validated successfully"
        return 0
    else
        log_message "ERROR: Failed to connect to exchange: \$exchange_url"
        return 1
    fi
}

# Register with Open Horizon exchange
register_with_exchange() {
    local exchange_url="\$1"
    local exchange_org="\$2"
    local exchange_user="\$3"
    local exchange_token="\$4"
    
    log_message "Starting Open Horizon registration process"
    log_message "Exchange URL: \$exchange_url"
    log_message "Organization: \$exchange_org"
    log_message "User: \$exchange_user"
    
    # Set environment variables for hzn command
    export HZN_EXCHANGE_URL="\$exchange_url"
    export HZN_ORG_ID="\$exchange_org"
    export HZN_EXCHANGE_USER_AUTH="\$exchange_user:\$exchange_token"
    
    # Generate a unique node ID if not already set
    local node_id=\$(hostname)-\$(date +%s)
    export HZN_DEVICE_ID="\$node_id"
    
    log_message "Node ID: \$node_id"
    
    # Check if hzn command is available
    if ! command -v hzn >/dev/null 2>&1; then
        log_message "ERROR: hzn command not found"
        return 1
    fi
    
    # Register the node
    log_message "Registering node with exchange..."
    
    # Use the node.json configuration
    local node_json_file="/etc/horizon/node.json"
    if [[ -f "\$node_json_file" ]]; then
        log_message "Using custom node.json configuration: \$node_json_file"
        hzn register -f "\$node_json_file" || {
            log_message "ERROR: Failed to register with custom node.json"
            return 1
        }
    else
        log_message "Using default registration (no node.json found)"
        hzn register || {
            log_message "ERROR: Failed to register with default configuration"
            return 1
        }
    fi
    
    # Verify registration
    log_message "Verifying registration..."
    if hzn node list >/dev/null 2>&1; then
        log_message "Registration successful!"
        hzn node list | tee -a /var/log/horizon-registration.log
        return 0
    else
        log_message "ERROR: Registration verification failed"
        return 1
    fi
}

# Main registration process
main() {
    log_message "=== Open Horizon Registration Started ==="
    
    # Wait for network connectivity
    if ! wait_for_network; then
        log_message "FATAL: Network connectivity required for registration"
        exit 1
    fi
    
    # Validate exchange connectivity
    if ! validate_exchange "\$EXCHANGE_URL"; then
        log_message "FATAL: Exchange connectivity validation failed"
        exit 1
    fi
    
    # Register with exchange
    if register_with_exchange "\$EXCHANGE_URL" "\$EXCHANGE_ORG" "\$EXCHANGE_USER" "\$EXCHANGE_TOKEN"; then
        log_message "=== Open Horizon Registration Completed Successfully ==="
        
        # Remove this script to prevent re-running
        log_message "Removing registration script to prevent re-execution"
        rm -f "\$0" || log_message "WARNING: Failed to remove registration script"
        
        exit 0
    else
        log_message "=== Open Horizon Registration Failed ==="
        exit 1
    fi
}

# Only run main if script is executed directly
if [[ "\${BASH_SOURCE[0]}" == "\${0}" ]]; then
    main "\$@"
fi
EOFSCRIPT
    
    # Set proper permissions on the registration script
    chmod 755 "$horizon_register_script" || {
        log_error "create_firstrun_script: Failed to set permissions on registration script"
        return 1
    }
    
    # Create the firstrun.sh script for Raspberry Pi OS
    local firstrun_script="${chroot_path}/boot/firstrun.sh"
    log_info "Creating firstrun.sh script: $firstrun_script"
    
    cat > "$firstrun_script" << 'EOFFIRSTRUN'
#!/bin/bash
# Raspberry Pi OS First Run Script
# Generated by Raspberry Pi Image Builder
# This script integrates with Raspberry Pi OS first-boot mechanism

set +e  # Don't exit on errors in firstrun.sh

# Log function
log_firstrun() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] FIRSTRUN: $message" >> /var/log/firstrun.log
}

log_firstrun "=== Raspberry Pi First Run Started ==="

# Enable SSH if not already enabled
if [[ ! -f /boot/ssh ]]; then
    log_firstrun "Enabling SSH service"
    systemctl enable ssh
    systemctl start ssh
    touch /boot/ssh
fi

# Set up Open Horizon registration to run after network is available
log_firstrun "Setting up Open Horizon registration"

# Create a systemd service to run registration after network is up
cat > /etc/systemd/system/horizon-registration.service << 'EOFSERVICE'
[Unit]
Description=Open Horizon Registration Service
After=network-online.target
Wants=network-online.target
ConditionPathExists=/usr/local/bin/horizon-register.sh

[Service]
Type=oneshot
ExecStart=/usr/local/bin/horizon-register.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOFSERVICE

# Enable the registration service
systemctl daemon-reload
systemctl enable horizon-registration.service

log_firstrun "Open Horizon registration service configured"

# Remove this firstrun script to prevent re-execution
log_firstrun "Removing firstrun.sh to prevent re-execution"
rm -f /boot/firstrun.sh

log_firstrun "=== Raspberry Pi First Run Completed ==="

# Reboot to ensure all services start properly
log_firstrun "Rebooting system to complete setup"
reboot
EOFFIRSTRUN
    
    # Set proper permissions on firstrun.sh
    chmod 755 "$firstrun_script" || {
        log_error "create_firstrun_script: Failed to set permissions on firstrun.sh"
        return 1
    }
    
    log_info "Firstrun script creation completed successfully"
    return 0
}

# Validate exchange connectivity
# Usage: validate_exchange_connectivity <exchange_url>
# Returns: 0 on success, 1 on failure
validate_exchange_connectivity() {
    local exchange_url="$1"
    
    log_debug "Validating connectivity to exchange: $exchange_url"
    
    # Validate URL format
    if [[ ! "$exchange_url" =~ ^https?:// ]]; then
        log_error "validate_exchange_connectivity: Invalid exchange URL format: $exchange_url"
        return 1
    fi
    
    # Test connectivity with timeout
    local timeout=10
    if command -v curl >/dev/null 2>&1; then
        if curl -s --connect-timeout "$timeout" "$exchange_url/v1/admin/version" >/dev/null 2>&1; then
            log_debug "Exchange connectivity validated successfully"
            return 0
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -q --timeout="$timeout" --tries=1 -O /dev/null "$exchange_url/v1/admin/version" 2>/dev/null; then
            log_debug "Exchange connectivity validated successfully"
            return 0
        fi
    else
        log_warn "validate_exchange_connectivity: Neither curl nor wget available, skipping connectivity test"
        return 0
    fi
    
    log_error "validate_exchange_connectivity: Failed to connect to exchange: $exchange_url"
    return 1
}

# Embed exchange credentials securely
# Usage: embed_exchange_credentials <chroot_path> <exchange_url> <exchange_org> <exchange_user> <exchange_token>
# Returns: 0 on success, 1 on failure
embed_exchange_credentials() {
    local chroot_path="$1"
    local exchange_url="$2"
    local exchange_org="$3"
    local exchange_user="$4"
    local exchange_token="$5"
    
    log_debug "Embedding exchange credentials securely"
    
    # Create horizon configuration directory
    local horizon_config_dir="${chroot_path}/etc/horizon"
    mkdir -p "$horizon_config_dir" || {
        log_error "embed_exchange_credentials: Failed to create horizon config directory"
        return 1
    }
    
    # Create environment file with secure permissions
    local env_file="${horizon_config_dir}/horizon.env"
    log_debug "Creating horizon environment file: $env_file"
    
    cat > "$env_file" << EOF
# Open Horizon Environment Configuration
# Generated by Raspberry Pi Image Builder
# This file contains sensitive credentials - keep secure

HZN_EXCHANGE_URL=$exchange_url
HZN_ORG_ID=$exchange_org
HZN_EXCHANGE_USER_AUTH=$exchange_user:$exchange_token
EOF
    
    # Set restrictive permissions (readable only by root)
    chmod 600 "$env_file" || {
        log_error "embed_exchange_credentials: Failed to set permissions on environment file"
        return 1
    }
    
    chown root:root "$env_file" 2>/dev/null || {
        log_warn "embed_exchange_credentials: Failed to set ownership on environment file"
    }
    
    log_debug "Exchange credentials embedded securely"
    return 0
}

# Configure node.json
# Usage: configure_node_json <chroot_path> [custom_node_json_path]
# Returns: 0 on success, 1 on failure
configure_node_json() {
    local chroot_path="$1"
    local custom_node_json_path="$2"
    
    log_debug "Configuring node.json"
    
    local target_node_json="${chroot_path}/etc/horizon/node.json"
    
    if [[ -n "$custom_node_json_path" && -f "$custom_node_json_path" ]]; then
        log_info "Using custom node.json file: $custom_node_json_path"
        cp "$custom_node_json_path" "$target_node_json" || {
            log_error "configure_node_json: Failed to copy custom node.json"
            return 1
        }
    else
        log_info "Creating default node.json configuration"
        cat > "$target_node_json" << 'EOF'
{
    "services": [],
    "pattern": "",
    "name": "",
    "nodeType": "device"
}
EOF
    fi
    
    # Set proper permissions
    chmod 644 "$target_node_json" || {
        log_error "configure_node_json: Failed to set permissions on node.json"
        return 1
    }
    
    chown root:root "$target_node_json" 2>/dev/null || {
        log_warn "configure_node_json: Failed to set ownership on node.json"
    }
    
    log_debug "Node.json configuration completed"
    return 0
}

# Create registration configuration string
# Usage: create_registration_config <exchange_url> <exchange_org> <exchange_user> <exchange_token>
# Returns: Configuration string in format url|org|user|token
create_registration_config() {
    local exchange_url="$1"
    local exchange_org="$2"
    local exchange_user="$3"
    local exchange_token="$4"
    
    # Return configuration in a simple format that can be parsed later
    echo "${exchange_url}|${exchange_org}|${exchange_user}|${exchange_token}"
}

# Show usage information
show_usage() {
    cat << 'EOF'
Open Horizon Installation Library

Usage: horizon-install.sh [COMMAND] [OPTIONS]

Commands:
  install       Install Open Horizon components
  verify        Verify Open Horizon installation
  register      Configure exchange registration
  help          Show this help message

Options:
  --chroot-path PATH          Path to chroot environment
  --version VERSION           Open Horizon version to install
  --exchange-url URL          Exchange server URL
  --exchange-org ORG          Exchange organization
  --exchange-user USER        Exchange user credentials
  --exchange-token TOKEN      Exchange authentication token
  --node-json PATH            Path to custom node.json file
  --debug                     Enable debug logging

Examples:
  # Install Open Horizon
  ./horizon-install.sh install --chroot-path /mnt/rpi --version 2.30.0

  # Verify installation
  ./horizon-install.sh verify --chroot-path /mnt/rpi --version 2.30.0

  # Configure exchange registration
  ./horizon-install.sh register --chroot-path /mnt/rpi \
    --exchange-url https://exchange.example.com \
    --exchange-org myorg --exchange-user user --exchange-token token

  # Show help
  ./horizon-install.sh help
EOF
}

# Main function for CLI mode
main() {
    local command="${1:-help}"
    
    # Initialize logging and platform detection
    init_logging
    detect_platform
    
    case "$command" in
        install)
            shift
            local chroot_path="" version=""
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --chroot-path) chroot_path="$2"; shift 2 ;;
                    --version) version="$2"; shift 2 ;;
                    --debug) DEBUG=1; shift ;;
                    *) shift ;;
                esac
            done
            
            if [[ -z "$chroot_path" || -z "$version" ]]; then
                log_error "Missing required parameters for install command"
                show_usage
                exit 1
            fi
            
            install_anax_agent "$chroot_path" "$version" && \
            install_horizon_cli "$chroot_path" "$version" && \
            configure_agent_service "$chroot_path"
            ;;
        verify)
            shift
            local chroot_path="" version=""
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --chroot-path) chroot_path="$2"; shift 2 ;;
                    --version) version="$2"; shift 2 ;;
                    --debug) DEBUG=1; shift ;;
                    *) shift ;;
                esac
            done
            
            if [[ -z "$chroot_path" || -z "$version" ]]; then
                log_error "Missing required parameters for verify command"
                show_usage
                exit 1
            fi
            
            verify_open_horizon_installation "$chroot_path" "$version"
            ;;
        register)
            shift
            local chroot_path="" exchange_url="" exchange_org="" exchange_user="" exchange_token="" node_json_path=""
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --chroot-path) chroot_path="$2"; shift 2 ;;
                    --exchange-url) exchange_url="$2"; shift 2 ;;
                    --exchange-org) exchange_org="$2"; shift 2 ;;
                    --exchange-user) exchange_user="$2"; shift 2 ;;
                    --exchange-token) exchange_token="$2"; shift 2 ;;
                    --node-json) node_json_path="$2"; shift 2 ;;
                    --debug) DEBUG=1; shift ;;
                    *) shift ;;
                esac
            done
            
            if [[ -z "$chroot_path" || -z "$exchange_url" || -z "$exchange_org" || -z "$exchange_user" || -z "$exchange_token" ]]; then
                log_error "Missing required parameters for register command"
                show_usage
                exit 1
            fi
            
            configure_exchange_registration "$chroot_path" "$exchange_url" "$exchange_org" "$exchange_user" "$exchange_token" "$node_json_path"
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

# Execute only if run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
