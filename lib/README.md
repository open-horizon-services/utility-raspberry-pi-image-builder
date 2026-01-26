# RPi Image Builder Libraries

This directory contains standalone utility libraries extracted from the main build-rpi-image.sh script. Each library can be used independently or as part of the main build process.

## Available Libraries

### Core Image Management (Cross-Platform)
- `platform-detect.sh` - Platform detection and dependency checking
- `image-mount.sh` - Cross-platform disk image mounting and unmounting
- `image-verify.sh` - Image integrity and format verification

### Open Horizon Integration (Linux-Only)
- `chroot-utils.sh` - ARM chroot environment setup with QEMU emulation
- `network-config.sh` - Wi-Fi and Ethernet network configuration
- `horizon-install.sh` - Open Horizon agent installation and exchange registration

### Usage

Each library can be used in two ways:

1. **As a library**: Source the script to use its functions
   ```bash
   source lib/image-mount.sh
   mount_image "/path/to/image.img" "/tmp/mount"
   
   source lib/network-config.sh
   configure_wifi "/mnt/rpi" "MySSID" "MyPassword" "WPA2"
   ```

2. **As a standalone tool**: Run directly with CLI interface
   ```bash
   # Core libraries
   ./lib/image-mount.sh mount /path/to/image.img /tmp/mount
   ./lib/image-verify.sh verify /path/to/image.img
   ./lib/platform-detect.sh detect
   
   # Open Horizon libraries
   ./lib/chroot-utils.sh setup /mnt/rpi
   ./lib/network-config.sh wifi /mnt/rpi "MySSID" "MyPassword" WPA2
   ./lib/horizon-install.sh install --chroot-path /mnt/rpi --version 2.30.0
   ```

### Library Details

For comprehensive documentation on each library, see [AGENTS.md](AGENTS.md).

**Quick reference:**
- **platform-detect.sh** (693 lines) - Detects OS, checks dependencies, provides installation guidance
- **image-mount.sh** (472 lines) - Mounts/unmounts disk images using losetup (Linux) or hdiutil (macOS)
- **image-verify.sh** (660 lines) - Validates image format, partition structure, filesystem integrity
- **chroot-utils.sh** (324 lines) - Sets up chroot with ARM emulation, executes commands in chroot
- **network-config.sh** (448 lines) - Configures wpa_supplicant, dhcpcd, Ethernet fallback
- **horizon-install.sh** (1,396 lines) - Installs anax agent, CLI, configures exchange registration

## Design Principles

- **Single Responsibility**: Each library handles one specific domain
- **Cross-Platform Support**: Core libraries (platform-detect, image-mount, image-verify) support Linux and macOS
- **Linux-Only Operations**: Open Horizon libraries require Linux for chroot and systemd operations
- **Dual-Mode Operation**: All libraries work as both importable modules and standalone CLI tools
- **Standalone**: Can be used independently of the main script
- **Consistent**: All libraries follow the same CLI patterns and error handling
- **Security-First**: Credentials stored with chmod 600, passwords redacted in logs

## Dependencies

### Core Libraries
- **Linux**: bash 4.0+, losetup, mount, umount, fdisk, parted, file
- **macOS**: bash 4.0+, hdiutil, diskutil

### Open Horizon Libraries (Linux-only)
- **Required**: sudo, chroot, systemd, qemu-user-static (for ARM emulation on x86)
- **Optional**: wget or curl (for package downloads)

## Security Notes

- Log files created in `lib/` directory (add to `.gitignore`)
- Credentials in `/etc/horizon/horizon.env` are chmod 600
- Wi-Fi passwords in `/etc/wpa_supplicant/wpa_supplicant.conf` are chmod 600
- All sensitive data redacted from logs with `[REDACTED]`