# Requirements Document

## Introduction

A cross-platform system for creating custom Raspberry Pi SD card images that include the Open Horizon anax agent and CLI, with optional automatic registration to an Open Horizon exchange and Wi-Fi network configuration. The system must work on both Linux and macOS bash environments and produce images compatible with Raspberry Pi Imager and standard Linux utilities.

## Glossary

- **Image_Builder**: The system that creates custom SD card images
- **Base_Image**: The original Raspberry Pi OS image used as foundation
- **Custom_Image**: The modified image with Open Horizon components installed
- **Anax_Agent**: The Open Horizon edge node agent software
- **Open_Horizon_CLI**: Command-line interface for Open Horizon management
- **Exchange**: Open Horizon management hub for device registration
- **Agent_Registry**: Persistent storage system for project information in AGENTS.md

## Requirements

### Requirement 1: Cross-Platform Image Creation

**User Story:** As a developer, I want to create custom Raspberry Pi images on both Linux and macOS, so that I can work in my preferred development environment.

#### Acceptance Criteria

1. WHEN the system runs on Linux bash, THE Image_Builder SHALL create valid SD card images
2. WHEN the system runs on macOS bash, THE Image_Builder SHALL create valid SD card images  
3. THE Image_Builder SHALL use only commands and utilities available on both platforms
4. WHEN platform-specific operations are needed, THE Image_Builder SHALL detect the platform and use appropriate commands

### Requirement 2: Open Horizon Integration

**User Story:** As an edge computing administrator, I want to embed Open Horizon components in Raspberry Pi images, so that devices boot ready for edge workload deployment.

#### Acceptance Criteria

1. WHEN creating a custom image, THE Image_Builder SHALL install the specified version of the Anax_Agent
2. WHEN creating a custom image, THE Image_Builder SHALL install the Open_Horizon_CLI
3. WHEN a version is specified, THE Image_Builder SHALL install that exact version of Open Horizon components
4. THE Image_Builder SHALL configure the Anax_Agent to start automatically on boot
5. WHEN installation fails, THE Image_Builder SHALL provide clear error messages and halt processing

### Requirement 3: Exchange Registration

**User Story:** As an edge computing administrator, I want devices to automatically register with my Open Horizon exchange, so that I can manage them immediately after deployment.

#### Acceptance Criteria

1. WHERE exchange registration is desired, THE Image_Builder SHALL configure automatic registration on first boot using cloud-init and firstrun.sh
2. WHEN exchange credentials are provided, THE Image_Builder SHALL securely embed them in the image
3. WHEN a custom node.json file is provided, THE Image_Builder SHALL use it for device registration
4. WHEN no custom node.json file is provided, THE Image_Builder SHALL use the default node.json configuration
5. THE Image_Builder SHALL use cloud-init to ensure registration occurs after network connectivity is established
6. THE Image_Builder SHALL integrate with Raspberry Pi OS firstrun.sh mechanism for first-boot setup
7. WHEN registration is configured, THE Image_Builder SHALL validate exchange connectivity during image creation
8. IF exchange registration fails during boot, THEN THE system SHALL log detailed error information
9. WHERE no exchange is specified, THE Image_Builder SHALL create images without registration configuration

### Requirement 4: Wi-Fi Network Configuration

**User Story:** As a device deployer, I want Raspberry Pi devices to automatically connect to my Wi-Fi network, so that they are immediately accessible after deployment.

#### Acceptance Criteria

1. WHERE Wi-Fi configuration is desired, THE Image_Builder SHALL embed network credentials in the image
2. WHEN Wi-Fi credentials are provided, THE Image_Builder SHALL configure automatic connection on boot
3. THE Image_Builder SHALL support WPA2 and WPA3 security protocols
4. WHEN Wi-Fi connection fails, THE system SHALL fall back to Ethernet if available
5. WHERE no Wi-Fi is specified, THE Image_Builder SHALL create images without wireless configuration

### Requirement 5: Image Compatibility

**User Story:** As a device deployer, I want to use standard tools to write images to SD cards, so that I can use familiar deployment workflows.

#### Acceptance Criteria

1. THE Image_Builder SHALL produce images compatible with Raspberry Pi Imager
2. THE Image_Builder SHALL produce images compatible with standard Linux utilities (dd, balenaEtcher)
3. WHEN images are created, THE Image_Builder SHALL verify image integrity
4. THE Custom_Image SHALL boot successfully on Raspberry Pi hardware
5. THE Custom_Image SHALL maintain all original Raspberry Pi OS functionality

### Requirement 6: Project Persistence

**User Story:** As a project manager, I want to track all created agent configurations, so that I can maintain an inventory of deployed devices.

#### Acceptance Criteria

1. WHEN an image is created, THE Agent_Registry SHALL record the configuration in AGENTS.md
2. THE Agent_Registry SHALL store Open Horizon version, exchange details, node.json configuration, and Wi-Fi configuration for each image
3. WHEN AGENTS.md exists, THE Agent_Registry SHALL append new entries without overwriting existing data
4. THE Agent_Registry SHALL include timestamps and unique identifiers for each configuration
5. THE Agent_Registry SHALL use markdown format for human readability

### Requirement 7: Configuration Management

**User Story:** As a system administrator, I want to specify image configurations through parameters, so that I can automate image creation for different deployment scenarios.

#### Acceptance Criteria

1. THE Image_Builder SHALL accept Open Horizon version as a parameter
2. THE Image_Builder SHALL accept exchange URL and credentials as optional parameters
3. THE Image_Builder SHALL accept custom node.json file path as an optional parameter
4. THE Image_Builder SHALL accept Wi-Fi SSID and password as optional parameters
5. THE Image_Builder SHALL accept base image path as a parameter
6. THE Image_Builder SHALL accept output image path as a parameter
7. THE Image_Builder SHALL accept cloud-init configuration options as optional parameters
8. WHEN required parameters are missing, THE Image_Builder SHALL prompt for input or use sensible defaults

### Requirement 8: Error Handling and Validation

**User Story:** As a developer, I want clear error messages when image creation fails, so that I can quickly resolve issues.

#### Acceptance Criteria

1. WHEN invalid parameters are provided, THE Image_Builder SHALL display specific error messages
2. WHEN base images are corrupted or missing, THE Image_Builder SHALL detect and report the issue
3. WHEN insufficient disk space exists, THE Image_Builder SHALL check and warn before processing
4. WHEN network connectivity is required but unavailable, THE Image_Builder SHALL provide clear guidance
5. THE Image_Builder SHALL validate all inputs before beginning image modification