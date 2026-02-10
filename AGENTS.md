# Raspberry Pi Image Builder - Project Knowledge Base

**Generated:** 2026-01-25T22:56:10  
**Structure:** Root → [lib/](lib/AGENTS.md)  
**Note:** Agent registry in [REGISTRY.md](REGISTRY.md), NOT here

Cross-platform script creating custom Raspberry Pi images with Open Horizon. Bash + BATS testing.

## Quick Start

### Build Commands
```bash
# Run main image builder script
./build-rpi-image.sh --oh-version "2.30.0" --base-image "raspios-lite.img" --output-image "custom-rpi.img"

# Show help and all available options
./build-rpi-image.sh --help

# List all registered agent configurations
./build-rpi-image.sh --list-agents

# Enable debug logging
DEBUG=1 ./build-rpi-image.sh --oh-version "2.30.0" --base-image "raspios-lite.img" --output-image "custom-rpi.img"
```

### Testing Commands
```bash
# Run all tests (when BATS framework is installed)
bats test/

# Run a specific test file
bats test/test-platform-detection.bats

# Run tests with verbose output
bats -t test/

# Run property-based tests (minimum 100 iterations per property)
bats test/property-tests/
```

### Lint and Format Commands
```bash
# Lint shell scripts for security and correctness issues
shellcheck build-rpi-image.sh

# Format shell scripts to consistent style
shfmt -w build-rpi-image.sh

# Lint all shell files in project
find . -name "*.sh" -exec shellcheck {} \;

# Format all shell files in project  
find . -name "*.sh" -exec shfmt -w {} \;

# Check shell script portability
shellcheck -o all -s bash build-rpi-image.sh
```

## Code Style Guidelines

### Bash Scripting Standards

#### Strict Mode and Error Handling
- **Always use strict mode**: `set -euo pipefail` at the top of every script
- **Trap errors**: `trap 'handle_error $LINENO' ERR` for proper error reporting
- **Cleanup handlers**: Implement `trap cleanup_on_exit EXIT` for resource cleanup
- **Signal handling**: Add `trap cleanup_on_signal INT TERM` for graceful interruption

#### Naming Conventions
- **Global variables**: Use `UPPER_CASE` with descriptive prefixes (e.g., `CONFIG_OH_VERSION`, `DETECTED_PLATFORM`)
- **Local variables**: Use `lower_case` and declare with `local` keyword inside functions
- **Functions**: Use `snake_case` with descriptive verbs (e.g., `mount_image_linux`, `validate_configuration`)
- **Constants**: Use `UPPER_CASE` and mark as readonly when appropriate
- **File names**: Use kebab-case for scripts (e.g., `build-rpi-image.sh`)

#### Import and Include Patterns
- **Script header**: Include shebang, description, and strict mode directive
- **Source dependencies**: Avoid sourcing external files; keep functionality self-contained
- **Function ordering**: Place helper functions before main functions that use them
- **Main function**: Use `main()` function and call it at the end with direct execution check

```bash
#!/bin/bash
# Script description
set -euo pipefail

# Global variables first
GLOBAL_VAR=""

# Helper functions next
helper_function() {
    local param="$1"
    # implementation
}

# Core functionality functions
core_function() {
    # implementation
}

# Main function last
main() {
    # orchestrate
}

# Execute only if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

#### Function Design Patterns
- **Single responsibility**: Each function should do one thing well
- **Input validation**: Validate parameters at function start
- **Return codes**: Use return values for success/failure (0=success, non-zero=failure)
- **Output**: Use `echo` for data output, logging functions for messages
- **Documentation**: Add function headers describing purpose, parameters, and return values

```bash
# Mount image filesystem with platform-specific implementation
# Usage: mount_image <image_path> <mount_point>
# Returns: 0 on success, 1 on failure, outputs loop device name
mount_image() {
    local image_path="$1"
    local mount_point="$2"
    
    # Validate inputs
    if [[ -z "$image_path" || -z "$mount_point" ]]; then
        log_error "mount_image: Missing required parameters"
        return 1
    fi
    
    # Implementation...
    return 0
}
```

#### Logging Standards
- **Logging levels**: Use standardized logging functions with timestamps
- **Structured messages**: Follow format `[timestamp] LEVEL: message`
- **Redaction**: Redact sensitive information (passwords, tokens) with `[REDACTED]`
- **Debug output**: Use `log_debug()` for verbose output controlled by `DEBUG` variable

```bash
log_info() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] INFO: $message" | tee -a "$LOG_FILE"
}

log_error() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] ERROR: $message" | tee -a "$LOG_FILE" >&2
}
```

#### Error Handling Patterns
- **Early validation**: Validate inputs before processing
- **Retry logic**: Implement retry patterns for transient failures
- **Resource cleanup**: Always clean up mounts, temporary files, and devices
- **Graceful degradation**: Fall back to optional functionality when possible
- **User guidance**: Provide clear error messages with suggested solutions

### Platform-Specific Guidelines

#### Cross-Platform Development
- **Detection first**: Always detect platform before using platform-specific tools
- **Tool arrays**: Use arrays to store platform-specific tool lists
- **Case statements**: Use `case` for platform-specific implementation branches
- **Fallback paths**: Provide fallbacks when optional tools are unavailable

```bash
detect_platform() {
    case "$(uname -s)" in
        Linux*)  DETECTED_PLATFORM="linux" ;;
        Darwin*) DETECTED_PLATFORM="macos" ;;
        *)
            log_error "Unsupported platform"
            exit 1
            ;;
    esac
}

select_platform_tools() {
    case "$DETECTED_PLATFORM" in
        linux)
            PLATFORM_TOOLS=("losetup" "mount" "umount")
            ;;
        macos)
            PLATFORM_TOOLS=("hdiutil" "diskutil")
            ;;
    esac
}
```

#### Linux-Specific Considerations
- **Sudo requirements**: Check for root privileges or sudo access for mount operations
- **Package managers**: Support multiple package managers (apt, yum, dnf) in installation guidance
- **Filesystem tools**: Use standard Linux filesystem utilities (fdisk, losetup, etc.)
- **Systemd integration**: Configure systemd services for automatic startup

#### macOS-Specific Considerations
- **Homebrew dependencies**: Provide Homebrew installation commands for optional tools
- **Filesystem differences**: Handle macOS-specific mount point and device naming
- **Security requirements**: Account for macOS security restrictions on disk operations
- **Tool availability**: Use built-in macOS tools (hdiutil, diskutil) when possible

### Testing Strategy

#### Property-Based Testing
- **BATS framework**: Use Bash Automated Testing System for all testing
- **Property tests**: Implement tests that validate universal properties across all valid inputs
- **Iteration count**: Run minimum 100 iterations per property test for comprehensive coverage
- **Test tagging**: Use format `Feature: raspberry-pi-image-builder, Property {number}: {description}`

#### Unit Testing
- **Edge cases**: Test specific error conditions and boundary cases
- **Integration points**: Verify component interactions work correctly
- **Platform coverage**: Test both Linux and macOS execution paths
- **Mock services**: Use mock services for external dependencies

#### Test Organization
```
test/
├── unit/                    # Unit tests for specific functions
├── property/               # Property-based tests
├── integration/            # End-to-end tests
├── fixtures/               # Test data and mock files
└── helpers.bats            # Common test utilities
```

### Security Considerations

#### Input Validation
- **Parameter validation**: Validate all user inputs before processing
- **Path traversal**: Prevent directory traversal attacks in file paths
- **Command injection**: Avoid constructing shell commands from user input
- **File permissions**: Check file permissions before sensitive operations

#### Credential Handling
- **No plaintext logging**: Redact passwords, tokens, and other sensitive data
- **Secure storage**: Use proper file permissions for credential files
- **Environment variables**: Consider using environment variables for sensitive data
- **Cleanup**: Remove temporary files containing sensitive data

### Development Workflow

#### Making Changes
1. **Read existing code**: Understand current patterns before making changes
2. **Follow conventions**: Use existing naming, error handling, and logging patterns
3. **Add tests**: Write tests for new functionality following the testing strategy
4. **Validate changes**: Run lint checks and tests before committing
5. **Update documentation**: Update function documentation and usage examples

#### Debugging
- **Enable debug mode**: Use `DEBUG=1` environment variable for verbose logging
- **Check logs**: Review `build-rpi-image.log` for detailed execution information
- **Platform testing**: Test changes on both Linux and macOS when possible
- **Error reproduction**: Use comprehensive logging to reproduce and fix issues

#### Code Review Checklist
- [ ] Uses strict mode (`set -euo pipefail`)
- [ ] Follows naming conventions
- [ ] Includes proper error handling
- [ ] Has input validation
- [ ] Uses logging functions appropriately
- [ ] Handles cleanup in error cases
- [ ] Works cross-platform (when applicable)
- [ ] Includes documentation for complex logic
- [ ] Passes shellcheck with no warnings
- [ ] Is formatted with shfmt
- [ ] Has corresponding tests

## Agent Registry

For a complete registry of all created agent configurations, see [REGISTRY.md](REGISTRY.md).

## Agent Configuration: 1770676979-059de3cc

- **Created**: 2026-02-09T22:42:59Z
- **Open Horizon Version**: 2.32.0-1753
- **Exchange URL**: none
- **Node JSON**: default
- **Wi-Fi SSID**: none
- **Base Image**: 2025-12-04-raspios-trixie-arm64-lite.img
- **Output Image**: custom-rpi.img
- **Status**: created

## Agent Configuration: 1770676979-059de3cc

- **Created**: 2026-02-09T22:42:59Z
- **Open Horizon Version**: 2.32.0-1753
- **Exchange URL**: none
- **Node JSON**: default
- **Wi-Fi SSID**: none
- **Base Image**: 2025-12-04-raspios-trixie-arm64-lite.img
- **Output Image**: custom-rpi.img
- **Status**: created


## Agent Configuration: 1770682333-941cd39c

- **Created**: 2026-02-10T00:12:13Z
- **Open Horizon Version**: 2.32.0-1753
- **Exchange URL**: none
- **Node JSON**: default
- **Wi-Fi SSID**: none
- **Base Image**: 2025-12-04-raspios-trixie-arm64-lite.img
- **Output Image**: custom-rpi.img
- **Status**: created

## Agent Configuration: 1770682333-941cd39c

- **Created**: 2026-02-10T00:12:13Z
- **Open Horizon Version**: 2.32.0-1753
- **Exchange URL**: none
- **Node JSON**: default
- **Wi-Fi SSID**: none
- **Base Image**: 2025-12-04-raspios-trixie-arm64-lite.img
- **Output Image**: custom-rpi.img
- **Status**: created

[2026-02-09 19:15:44] DEBUG: Creating registry entry for agent ID: 1770682544-892471f1
[2026-02-09 19:15:44] DEBUG: Creating registry entry for agent ID: 1770682544-892471f1

## Agent Configuration: 1770682544-892471f1

- **Created**: 2026-02-10T00:15:44Z
- **Open Horizon Version**: 2.32.0-1753
- **Exchange URL**: none
- **Node JSON**: default
- **Wi-Fi SSID**: none
- **Base Image**: 2025-12-04-raspios-trixie-arm64-lite.img
- **Output Image**: custom-rpi.img
- **Status**: created
[2026-02-09 19:15:44] DEBUG: Creating registry entry for agent ID: 1770682544-892471f1
[2026-02-09 19:15:44] DEBUG: Creating registry entry for agent ID: 1770682544-892471f1

## Agent Configuration: 1770682544-892471f1

- **Created**: 2026-02-10T00:15:44Z
- **Open Horizon Version**: 2.32.0-1753
- **Exchange URL**: none
- **Node JSON**: default
- **Wi-Fi SSID**: none
- **Base Image**: 2025-12-04-raspios-trixie-arm64-lite.img
- **Output Image**: custom-rpi.img
- **Status**: created
