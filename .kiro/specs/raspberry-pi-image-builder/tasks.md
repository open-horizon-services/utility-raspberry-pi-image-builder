# Implementation Plan: Raspberry Pi Image Builder

## Overview

Implementation of a cross-platform Bash script system that creates custom Raspberry Pi SD card images with embedded Open Horizon components. The system will use platform-specific tools for image mounting and modification, with comprehensive error handling and project persistence.

## Tasks

- [x] 1. Set up project structure and core utilities
  - Create main script `build-rpi-image.sh` with proper shebang and error handling
  - Create utility functions for logging, error handling, and cleanup
  - Set up configuration parsing and validation framework
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8_

- [ ]* 1.1 Write property test for parameter acceptance
  - **Property 19: Parameter acceptance and handling**
  - **Validates: Requirements 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7**

- [x] 2. Implement platform detection and dependency checking
  - Create `detect_platform()` function to identify Linux vs macOS
  - Implement `check_dependencies()` to verify required tools are available
  - Add platform-specific tool selection logic
  - _Requirements: 1.4_

- [ ]* 2.1 Write property test for platform detection
  - **Property 2: Platform detection and tool selection**
  - **Validates: Requirements 1.4**

- [x] 3. Implement image mounting and management
  - Create `mount_image()` function with Linux losetup and macOS hdiutil support
  - Implement `unmount_image()` with proper cleanup for both platforms
  - Add `verify_image()` function for integrity checking
  - Include error handling and retry logic for mount operations
  - _Requirements: 1.1, 1.2, 5.3, 8.2_

- [ ]* 3.1 Write property test for cross-platform image creation
  - **Property 1: Cross-platform image creation**
  - **Validates: Requirements 1.1, 1.2**

- [ ]* 3.2 Write property test for image integrity verification
  - **Property 14: Image integrity verification**
  - **Validates: Requirements 5.3**

- [x] 4. Implement Open Horizon component installation
  - Create `install_anax_agent()` function with version-specific installation
  - Implement `install_horizon_cli()` with proper ARM architecture handling
  - Add `configure_agent_service()` for systemd service setup
  - Include chroot environment setup with qemu-user-static for ARM emulation
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

- [ ]* 4.1 Write property test for exact version installation
  - **Property 3: Exact version installation**
  - **Validates: Requirements 2.1, 2.3**

- [ ]* 4.2 Write property test for CLI installation verification
  - **Property 4: CLI installation verification**
  - **Validates: Requirements 2.2**

- [ ]* 4.3 Write property test for service auto-start configuration
  - **Property 5: Service auto-start configuration**
  - **Validates: Requirements 2.4**

- [x] 5. Checkpoint - Ensure core functionality works
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Implement network configuration module
  - Create `configure_wifi()` function for wpa_supplicant setup
  - Support WPA2 and WPA3 security protocols
  - Add conditional Wi-Fi configuration based on parameters
  - _Requirements: 4.1, 4.2, 4.3, 4.5_

- [ ]* 6.1 Write property test for conditional Wi-Fi configuration
  - **Property 10: Conditional Wi-Fi configuration**
  - **Validates: Requirements 4.1, 4.5**

- [ ]* 6.2 Write property test for Wi-Fi security protocol support
  - **Property 12: Wi-Fi security protocol support**
  - **Validates: Requirements 4.3**

- [x] 7. Implement exchange registration with cloud-init
  - Create `configure_exchange_registration()` function
  - Implement `setup_cloud_init()` for first-boot configuration
  - Create `create_firstrun_script()` for Raspberry Pi OS integration
  - Add support for custom node.json files with fallback to defaults
  - Include secure credential embedding with proper permissions
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.9_

- [ ]* 7.1 Write property test for conditional exchange registration
  - **Property 7: Conditional exchange registration**
  - **Validates: Requirements 3.1, 3.3, 3.4, 3.5, 3.6, 3.9**

- [ ]* 7.2 Write property test for secure credential embedding
  - **Property 8: Secure credential embedding**
  - **Validates: Requirements 3.2**

- [x] 8. Implement project registry system
  - Create `register_agent()` function for AGENTS.md management
  - Implement markdown formatting for registry entries
  - Add append functionality to preserve existing entries
  - Include timestamp and unique identifier generation
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

- [ ]* 8.1 Write property test for registry entry creation
  - **Property 15: Registry entry creation**
  - **Validates: Requirements 6.1**

- [ ]* 8.2 Write property test for registry entry completeness
  - **Property 16: Registry entry completeness**
  - **Validates: Requirements 6.2, 6.4**

- [ ]* 8.3 Write property test for registry append behavior
  - **Property 17: Registry append behavior**
  - **Validates: Requirements 6.3**

- [ ] 9. Implement comprehensive error handling and validation
  - Add input validation for all parameters with specific error messages
  - Implement disk space checking before image operations
  - Add network connectivity validation for exchange and repositories
  - Create cleanup procedures for failed operations
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [ ]* 9.1 Write property test for input validation error reporting
  - **Property 21: Input validation error reporting**
  - **Validates: Requirements 8.1**

- [ ]* 9.2 Write property test for base image validation
  - **Property 22: Base image validation**
  - **Validates: Requirements 8.2**

- [ ]* 9.3 Write property test for pre-modification validation
  - **Property 25: Pre-modification input validation**
  - **Validates: Requirements 8.5**

- [x] 10. Implement image format compatibility verification
  - Add image format validation for Raspberry Pi Imager compatibility
  - Verify compatibility with standard Linux utilities (dd, balenaEtcher)
  - Include partition table and filesystem structure validation
  - _Requirements: 5.1, 5.2_

- [ ]* 10.1 Write property test for image format compatibility
  - **Property 13: Image format compatibility**
  - **Validates: Requirements 5.1, 5.2**

- [x] 11. Integration and main script assembly
  - Wire all modules together in main script
  - Implement command-line argument parsing
  - Add usage help and documentation
  - Create comprehensive logging throughout the process
  - _Requirements: 1.1, 1.2, 1.4_

- [x] 11.1 Write unit tests for command-line interface
  - Test help output, argument parsing, and error conditions
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8_

- [x] 12. Final checkpoint and integration testing
  - Ensure all tests pass, ask the user if questions arise.
  - Verify end-to-end functionality with sample configurations
  - Test both Linux and macOS execution paths

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Property tests validate universal correctness properties using BATS framework
- Unit tests validate specific examples and edge cases
- Checkpoints ensure incremental validation of core functionality
- All bash scripts should include proper error handling with `set -euo pipefail`
- Use shellcheck for static analysis of bash scripts during development