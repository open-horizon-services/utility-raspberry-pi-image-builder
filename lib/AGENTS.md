# lib/ - Utility Libraries

**Parent:** [../AGENTS.md](../AGENTS.md)  
**Purpose:** Modular utilities for platform detection, image mounting, and verification

## OVERVIEW

6 standalone libraries (4,168 lines total). Each usable as CLI tool OR imported library. Core libs cross-platform (Linux/macOS), OH libs Linux-only (chroot required).

## STRUCTURE

```
lib/
├── platform-detect.sh   # 693 lines, 27 functions - Platform + dependency detection
├── image-mount.sh       # 472 lines, 16 functions - Mount/unmount disk images
├── image-verify.sh      # 660 lines, 19 functions - Image integrity + format checks
├── chroot-utils.sh      # 324 lines, 3 functions - ARM chroot environment setup
├── network-config.sh    # 448 lines, 4 functions - Wi-Fi and network configuration
├── horizon-install.sh   # 1,396 lines, 16 functions - Open Horizon installation
└── README.md            # Library usage documentation
```

## WHERE TO LOOK

| Task | File | Key Functions |
|------|------|---------------|
| Detect OS, check tools | `platform-detect.sh` | `detect_platform()`, `check_dependencies()`, `provide_installation_guidance()` |
| Mount RPi image | `image-mount.sh` | `mount_image()`, `mount_image_linux()`, `mount_image_macos()` |
| Verify image format | `image-verify.sh` | `verify_image()`, `verify_partition_structure()`, `verify_filesystem_structure()` |
| Set up ARM chroot | `chroot-utils.sh` | `setup_chroot_environment()`, `chroot_exec()`, `cleanup_chroot_mounts()` |
| Configure Wi-Fi | `network-config.sh` | `configure_wifi()`, `validate_wifi_configuration()`, `configure_network_fallback()` |
| Install Open Horizon | `horizon-install.sh` | `install_anax_agent()`, `install_horizon_cli()`, `configure_agent_service()`, `configure_exchange_registration()` |
| Platform-specific paths | All core libs | Each has `case "$DETECTED_PLATFORM" in` blocks |

## DUAL-MODE OPERATION

Each library supports two usage modes:

**Library Mode** (sourced by main script):
```bash
source lib/platform-detect.sh
detect_platform  # Sets DETECTED_PLATFORM global
```

**CLI Mode** (standalone tool):
```bash
./lib/platform-detect.sh detect
./lib/image-mount.sh mount /path/to/image.img /tmp/mount
./lib/image-verify.sh verify /path/to/image.img
./lib/chroot-utils.sh setup /mnt/rpi
./lib/network-config.sh wifi /mnt/rpi "MySSID" "MyPassword" WPA2
./lib/horizon-install.sh install --chroot-path /mnt/rpi --version 2.30.0
```

## CONVENTIONS (Deviations from Parent)

### Dynamic Library Loading Pattern
Main script uses lazy-load wrapper pattern (NOT standard sourcing at top):

```bash
# In build-rpi-image.sh
detect_platform() {
    source "${SCRIPT_DIR}/lib/platform-detect.sh"  # Load on first call
    detect_platform  # Recursive call to sourced function
}
```

**Why:** Allows CLI mode while avoiding duplicate definitions. See build-rpi-image.sh lines 123-127 for pattern.

### Logging Initialization
Each library initializes own logging if not already set:

```bash
init_logging() {
    if [[ -z "${LOG_FILE:-}" ]]; then
        LOG_FILE="${SCRIPT_DIR}/platform-detect.log"  # Default to lib dir
        echo "=== Started at $(date) ===" > "$LOG_FILE"
    fi
}
```

**Issue:** Creates log files in source directory (`.gitignore` them or set `LOG_FILE` env var before sourcing).

### Platform Detection Variables
All three libraries declare but libraries don't share state:

```bash
DETECTED_PLATFORM=""  # Redeclared in each library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

**Implication:** If using multiple libraries standalone, detect platform in each OR export variables.

## ANTI-PATTERNS (Library-Specific)

- **NEVER** source a library inside a function with same name as library function (creates recursion, but this project uses it intentionally)
- **NEVER** assume `LOG_FILE` is set - always call `init_logging()` first
- **NEVER** assume another library's globals are available - each is independent
- **DO NOT** use library CLI mode + library mode simultaneously (confusing error messages)

## CROSS-PLATFORM IMPLEMENTATION

All platform-specific logic uses same pattern:

```bash
case "$DETECTED_PLATFORM" in
    linux)
        # Linux implementation using losetup, mount, etc.
        ;;
    macos)
        # macOS implementation using hdiutil, diskutil
        ;;
    *)
        log_error "Unsupported platform: $DETECTED_PLATFORM"
        return 1
        ;;
esac
```

**Linux tools:** `losetup`, `mount`, `umount`, `fdisk`, `parted`, `file`  
**macOS tools:** `hdiutil`, `diskutil`  
**Cross-platform:** `bash`, `grep`, `awk`, `sed`, `dd`

## DEPENDENCY CATEGORIES

`platform-detect.sh` organizes tools into categories (affects `check_dependencies` calls):

- `core` - Required for basic operation (bash 4.0+, standard utils)
- `optional` - Enhances functionality (shellcheck, shfmt)
- `mounting` - Image mount operations (losetup/hdiutil)
- `verification` - Image validation (file, fdisk, parted)
- `networking` - Wi-Fi config (nmcli, networksetup)

Call with specific categories: `check_dependencies mounting verification`

## UNIQUE PATTERNS

### Error Handling in Libraries
Libraries don't `exit` on error in library mode - they `return 1`:

```bash
if [[ ! -f "$image_path" ]]; then
    log_error "Image file not found: $image_path"
    return 1  # NOT exit 1 - allows caller to handle
fi
```

CLI mode (`main()` function) converts returns to exits.

### Platform-Specific Function Delegation
Libraries define both generic + platform-specific versions:

```bash
mount_image() {  # Generic dispatcher
    case "$DETECTED_PLATFORM" in
        linux)  mount_image_linux "$@" ;;
        macos)  mount_image_macos "$@" ;;
    esac
}

mount_image_linux() {  # Linux-specific implementation
    # losetup-based mounting
}

mount_image_macos() {  # macOS-specific implementation
    # hdiutil-based mounting
}
```

### Cleanup Tracking
`image-mount.sh` tracks mounted devices globally:

```bash
MOUNTED_DEVICES=()  # Array of loop devices/disk images

mount_image() {
    # ... mount logic ...
    MOUNTED_DEVICES+=("$loop_device")  # Track for cleanup
}

cleanup_mounts() {
    for device in "${MOUNTED_DEVICES[@]}"; do
        unmount_image "$device" "$mount_point"
    done
}
```

Caller must implement `trap cleanup_mounts EXIT` if using in library mode.

## TESTING

Each library has corresponding tests in `test/integration/`:

- `platform-detect.sh` → Tested in all integration tests (always called first)
- `image-mount.sh` → Tested with minimal 100MB test images
- `image-verify.sh` → Tested with MBR signature validation

No standalone unit tests for libraries - integrated via main script tests.

## OPEN HORIZON LIBRARIES (Linux-Only)

### chroot-utils.sh (324 lines)
**Purpose:** Cross-architecture ARM emulation setup for x86 build hosts

**Key Functions:**
- `setup_chroot_environment()` - Mounts /proc, /sys, /dev; copies qemu-aarch64-static for ARM emulation
- `chroot_exec()` - Executes commands inside chroot with platform checks (Linux-only)
- `cleanup_chroot_mounts()` - Unmounts chroot filesystems

**Dependencies:** qemu-user-static (Linux), sudo privileges

**CLI Usage:**
```bash
./chroot-utils.sh setup /mnt/rpi      # Set up chroot environment
./chroot-utils.sh exec /mnt/rpi "apt-get update"  # Execute command
./chroot-utils.sh cleanup /mnt/rpi    # Clean up mounts
```

### network-config.sh (448 lines)
**Purpose:** Wi-Fi and Ethernet configuration for Raspberry Pi OS

**Key Functions:**
- `configure_wifi()` - Creates wpa_supplicant.conf, enables services (WPA2/WPA3)
- `validate_wifi_configuration()` - Validates SSID (≤32 bytes), password (8-63 chars)
- `configure_network_fallback()` - Sets up Ethernet fallback in dhcpcd.conf
- `is_wifi_configuration_requested()` - Helper for main script

**Dependencies:** chroot-utils.sh (for service enablement)

**Security:** wpa_supplicant.conf created with chmod 600

**CLI Usage:**
```bash
./network-config.sh wifi /mnt/rpi "MyNetwork" "MyPassword" WPA2
./network-config.sh validate "MyNetwork" "MyPassword" WPA2
./network-config.sh fallback /mnt/rpi
```

### horizon-install.sh (1,396 lines)
**Purpose:** Open Horizon agent installation and exchange registration

**Key Functions:**
- `install_anax_agent()` - Downloads horizon_${version}_arm64.deb from GitHub, installs via dpkg
- `install_horizon_cli()` - Installs horizon-cli_${version}_arm64.deb
- `configure_agent_service()` - Enables horizon systemd service, creates /etc/horizon/anax.json
- `verify_open_horizon_installation()` - Checks for hzn binary, service files, config dirs
- `configure_exchange_registration()` - Master orchestrator for exchange registration
- `setup_cloud_init()` - Creates cloud-init configs in /etc/cloud/cloud.cfg.d/
- `create_firstrun_script()` - Creates /boot/firstrun.sh and /usr/local/bin/horizon-register.sh
- `validate_exchange_connectivity()` - Tests connection to exchange URL
- `embed_exchange_credentials()` - Creates /etc/horizon/horizon.env (chmod 600)
- `configure_node_json()` - Copies/creates /etc/horizon/node.json
- `create_registration_config()` - Formats config as pipe-delimited string

**Dependencies:** chroot-utils.sh, network connectivity (for downloads)

**Security:** Credentials stored in /etc/horizon/horizon.env with chmod 600

**CLI Usage:**
```bash
./horizon-install.sh install --chroot-path /mnt/rpi --version 2.30.0
./horizon-install.sh verify --chroot-path /mnt/rpi --version 2.30.0
./horizon-install.sh register --chroot-path /mnt/rpi \
  --exchange-url https://exchange.example.com \
  --exchange-org myorg --exchange-user admin --exchange-token token123
```

**First-Boot Behavior:**
1. cloud-init runs /usr/local/bin/horizon-register.sh
2. Script waits for network, validates exchange connectivity
3. Registers node with `hzn register` using /etc/horizon/node.json
4. Removes itself to prevent re-execution

## GOTCHAS

1. **Log file pollution:** Libraries create `.log` files in `lib/` directory. Set `LOG_FILE` env var to override.
2. **Recursive sourcing:** Dynamic loading pattern sources library inside function with same name - looks like recursion but isn't (intended design).
3. **State isolation:** Libraries don't share globals unless explicitly exported by caller.
4. **CLI vs library mode:** Don't mix - source OR execute, not both.
5. **Platform detection timing:** Must call `detect_platform()` before any platform-specific functions.
6. **Chroot dependencies:** network-config.sh and horizon-install.sh require chroot-utils.sh to be sourced first.
7. **Linux-only operations:** Chroot, systemd service management, and ARM emulation only work on Linux hosts.

## MODIFICATIONS

When editing libraries:
- Maintain dual-mode operation (check `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]` pattern)
- Update both generic + platform-specific versions of functions
- Test on both Linux AND macOS
- Run `shellcheck lib/*.sh` before committing
- Update corresponding sections in parent AGENTS.md if changing interfaces
