# Raspberry Pi Image Builder

A cross-platform tool for creating custom Raspberry Pi SD card images with embedded Open Horizon edge computing components. Build images on Linux or macOS that boot ready for edge workload deployment.

## Features

- **Cross-Platform**: Works on both Linux and macOS bash environments
- **Open Horizon Integration**: Automatically installs and configures Open Horizon anax agent and CLI
- **Exchange Registration**: Optional automatic registration with Open Horizon exchange on first boot
- **Wi-Fi Configuration**: Pre-configure Wi-Fi credentials for headless deployment
- **Image Compatibility**: Produces images compatible with Raspberry Pi Imager, dd, and balenaEtcher
- **Project Tracking**: Maintains registry of all created agent configurations

## Quick Start

### Prerequisites

**Linux:**
- Bash 4.0+
- Root/sudo access for mounting operations
- Standard utilities: `losetup`, `mount`, `umount`, `fdisk`, `file`

**macOS:**
- Bash 4.0+
- Built-in utilities: `hdiutil`, `diskutil`
- Optional: Homebrew for additional tools

### Basic Usage

```bash
# Create a basic image with Open Horizon
./build-rpi-image.sh \
  --oh-version "2.30.0" \
  --base-image "2024-11-19-raspios-bookworm-arm64-lite.img" \
  --output-image "custom-rpi.img"

# Create image with exchange registration
./build-rpi-image.sh \
  --oh-version "2.30.0" \
  --base-image "raspios-lite.img" \
  --output-image "custom-rpi.img" \
  --exchange-url "https://exchange.example.com" \
  --exchange-org "myorg" \
  --exchange-user "admin" \
  --exchange-token "my-secret-token"

# Create image with Wi-Fi pre-configured
./build-rpi-image.sh \
  --oh-version "2.30.0" \
  --base-image "raspios-lite.img" \
  --output-image "custom-rpi.img" \
  --wifi-ssid "MyNetwork" \
  --wifi-password "mypassword" \
  --wifi-security "WPA2"
```

### Get Help

```bash
# Show all available options
./build-rpi-image.sh --help

# List all registered agent configurations
./build-rpi-image.sh --list-agents

# Enable debug logging
DEBUG=1 ./build-rpi-image.sh --oh-version "2.30.0" --base-image "raspios-lite.img" --output-image "custom-rpi.img"
```

## Command-Line Options

### Required Options

| Option | Description |
|--------|-------------|
| `--oh-version VERSION` | Open Horizon version to install (e.g., "2.30.0") |
| `--base-image PATH` | Path to base Raspberry Pi OS image |
| `--output-image PATH` | Path for output custom image |

### Optional Options

| Option | Description | Default |
|--------|-------------|---------|
| `--exchange-url URL` | Open Horizon exchange URL | None |
| `--exchange-org ORG` | Exchange organization | None |
| `--exchange-user USER` | Exchange username | None |
| `--exchange-token TOKEN` | Exchange authentication token | None |
| `--node-json PATH` | Path to custom node.json file | Default config |
| `--wifi-ssid SSID` | Wi-Fi network name | None |
| `--wifi-password PASS` | Wi-Fi password | None |
| `--wifi-security TYPE` | Wi-Fi security (WPA2/WPA3) | WPA2 |
| `--mount-point PATH` | Temporary mount point | /tmp/rpi_mount |
| `--debug` | Enable debug logging | Disabled |
| `--list-agents` | List registered configurations | - |
| `--help, -h` | Show help message | - |

## How It Works

The build process follows these steps:

1. **Platform Detection**: Automatically detects Linux or macOS and checks dependencies
2. **Configuration Validation**: Validates all provided parameters and file paths
3. **Image Mounting**: Mounts the base Raspberry Pi OS image using platform-specific tools
4. **Open Horizon Installation**: Installs anax agent and CLI in specified version
5. **Service Configuration**: Configures automatic service startup using systemd
6. **Network Setup** (optional): Configures Wi-Fi credentials for automatic connection
7. **Exchange Registration** (optional): Sets up automatic registration using cloud-init and firstrun.sh
8. **Verification**: Validates the custom image for compatibility and integrity
9. **Registry Update**: Records the configuration in REGISTRY.md for tracking
10. **Image Finalization**: Unmounts and saves the custom image

## Project Structure

```
raspberry-pi-image-builder/
├── build-rpi-image.sh          # Main build script
├── lib/                         # Utility libraries
│   ├── platform-detect.sh      # Platform detection and dependency checking
│   ├── image-mount.sh          # Cross-platform image mounting
│   ├── image-verify.sh         # Image verification and validation
│   ├── chroot-utils.sh         # ARM chroot environment setup (Linux-only)
│   ├── network-config.sh       # Wi-Fi and network configuration
│   └── horizon-install.sh      # Open Horizon installation and setup
├── test/                        # Test suite
│   ├── unit/                   # Unit tests
│   ├── property/               # Property-based tests
│   └── integration/            # Integration tests
├── REGISTRY.md                  # Registry of created configurations
├── LICENSE                      # Apache 2.0 license
└── README.md                    # This file
```

## Libraries

The project includes modular libraries that can be used independently:

### Core Image Management (Cross-Platform)
- **platform-detect.sh**: Platform detection, dependency checking, installation guidance
- **image-mount.sh**: Disk image mounting/unmounting for Linux and macOS
- **image-verify.sh**: Image integrity and format verification

### Open Horizon Integration (Linux-Only)
- **chroot-utils.sh**: ARM chroot environment setup with QEMU emulation
- **network-config.sh**: Wi-Fi and Ethernet network configuration
- **horizon-install.sh**: Open Horizon agent installation and exchange registration

See [lib/README.md](lib/README.md) for detailed library documentation.

## Configuration Registry

Every created image configuration is automatically recorded in `REGISTRY.md` with:

- Unique agent ID and timestamp
- Open Horizon version
- Exchange URL and organization (if configured)
- Node configuration details
- Wi-Fi settings (SSID only, password redacted)
- Base and output image names
- Configuration status

View the registry:
```bash
./build-rpi-image.sh --list-agents
# or
cat REGISTRY.md
```

## Development

### Running Tests

```bash
# Install BATS (Bash Automated Testing System)
# macOS: brew install bats-core
# Linux: sudo apt-get install bats

# Verify BATS is installed
bats --version

# Run all unit tests (from project root)
bats test/unit/

# Run specific test file
bats test/unit/test-cli.bats

# View test summary
bats test/unit/ 2>&1 | grep -E "^(ok|not ok|# )" | head -25

# Count passing vs failing tests
bats test/unit/ 2>&1 | grep -c "^ok"        # Passing
bats test/unit/ 2>&1 | grep -c "^not ok"    # Failing
```

**Test Suite:** 20 CLI tests covering argument parsing, validation, and configuration.

**Linux Note:** Ubuntu's default BATS (1.2.1) is outdated. For full test support:
```bash
# Install latest BATS from source on Linux
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

### Code Quality

```bash
# Lint shell scripts
shellcheck build-rpi-image.sh
shellcheck lib/*.sh

# Format shell scripts
shfmt -w build-rpi-image.sh
shfmt -w lib/*.sh

# Check portability
shellcheck -o all -s bash build-rpi-image.sh
```

### Debugging

Enable debug mode for verbose logging:
```bash
DEBUG=1 ./build-rpi-image.sh --oh-version "2.30.0" --base-image "raspios-lite.img" --output-image "custom-rpi.img"
```

All execution details are logged to `build-rpi-image.log` in the script directory.

## Architecture

### Design Principles

- **Cross-platform compatibility**: Works identically on Linux and macOS
- **Modular design**: Functionality separated into reusable libraries
- **Strict error handling**: `set -euo pipefail` with comprehensive error trapping
- **Secure credential handling**: Sensitive data redacted in logs
- **Comprehensive logging**: Timestamped logs with multiple severity levels
- **Graceful cleanup**: Automatic resource cleanup on success, failure, or interruption

### Platform-Specific Operations

The tool automatically detects the platform and uses appropriate commands:

| Operation | Linux | macOS |
|-----------|-------|-------|
| Mount image | `losetup` + `mount` | `hdiutil attach` |
| Unmount image | `umount` + `losetup -d` | `hdiutil detach` |
| Disk info | `fdisk`, `parted` | `diskutil` |
| Chroot setup | QEMU user emulation | N/A (not supported) |

## Security Considerations

- **Credential Redaction**: Passwords and tokens are redacted in all log output
- **File Permissions**: Temporary files containing credentials are properly secured
- **Input Validation**: All user inputs are validated before processing
- **Root Requirements**: Linux mounting requires root/sudo; proper privilege checks are performed
- **Cleanup**: Sensitive temporary files are removed on exit

## Troubleshooting

### Common Issues

**Issue**: "Failed to mount base image"
- **Linux**: Ensure you have root/sudo access and `losetup` is available
- **macOS**: Check that the image file is not corrupted and `hdiutil` works

**Issue**: "Core dependency check failed"
- Run the script with `--help` to see platform-specific installation commands
- Install missing dependencies using your package manager

**Issue**: "Exchange registration validation failed"
- Verify exchange URL is accessible from your network
- Check credentials are correct
- Ensure exchange organization exists

**Issue**: Image won't boot on Raspberry Pi
- Verify the base image is compatible with your Raspberry Pi model
- Check that the output image wasn't corrupted during transfer to SD card
- Review `build-rpi-image.log` for any errors during image creation

### Getting More Information

1. Enable debug mode: `DEBUG=1`
2. Check the log file: `build-rpi-image.log`
3. Verify platform dependencies: `./build-rpi-image.sh --help`
4. Test base image: Use Raspberry Pi Imager to write the original base image and verify it boots

## Contributing

Contributions are welcome! Please follow these guidelines:

1. **Code Style**: Follow existing bash scripting conventions (see AGENTS.md)
2. **Testing**: Add tests for new functionality
3. **Documentation**: Update documentation for new features
4. **Linting**: Run `shellcheck` and `shfmt` before submitting
5. **Cross-Platform**: Ensure changes work on both Linux and macOS

See [AGENTS.md](AGENTS.md) for detailed coding standards and development guidelines.

## License

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for details.

## Related Documentation

- [AGENTS.md](AGENTS.md) - Project knowledge base and coding standards
- [REGISTRY.md](REGISTRY.md) - Registry of created agent configurations
- [lib/README.md](lib/README.md) - Library documentation
- [lib/AGENTS.md](lib/AGENTS.md) - Library implementation details

## About Open Horizon

[Open Horizon](https://www.lfedge.org/projects/openhorizon/) is an open-source edge computing platform that enables autonomous management of applications and machine learning workloads on edge devices. This tool simplifies deploying Open Horizon agents to Raspberry Pi devices at scale.

## Support

For issues, questions, or contributions, please refer to the project's issue tracker or documentation.
