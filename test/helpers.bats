#!/bin/bash
# Test helpers for BATS framework
# Provides common utilities for testing build-rpi-image.sh

# Load the main script functions (without executing main)
load_script() {
    # Source the main script in a way that loads functions but doesn't execute main
    # This approach allows us to test individual functions
    source "${BATS_TEST_DIRNAME}/../build-rpi-image.sh" 2>/dev/null || {
        # If direct sourcing fails, try to extract functions
        source "${BATS_TEST_DIRNAME}/../build-rpi-image.sh"
    }
}

# Helper to create temporary test files
create_test_file() {
    local filename="$1"
    local content="$2"
    local test_dir="${BATS_TMP_DIR:-/tmp/bats_test}"
    
    mkdir -p "$test_dir"
    echo "$content" > "${test_dir}/${filename}"
    echo "${test_dir}/${filename}"
}

# Helper to create temporary test image file
create_test_image() {
    local filename="$1"
    local size="${2:-100M}"
    local test_dir="${BATS_TMP_DIR:-/tmp/bats_test}"
    
    mkdir -p "$test_dir"
    
    # Create a minimal test image file with MBR signature
    local image_path="${test_dir}/${filename}"
    
    # Create a small file with proper MBR signature (0x55AA at end of first sector)
    {
        # First 510 bytes - zeros
        dd if=/dev/zero bs=510 count=1 2>/dev/null
        # MBR signature
        printf '\x55\xAA'
        # Add some more data to make it a reasonable size
        dd if=/dev/zero bs=1M count=100 2>/dev/null
    } > "$image_path"
    
    echo "$image_path"
}

# Helper to capture stdout and stderr
run_script_with_args() {
    local script_path="${BATS_TEST_DIRNAME}/../build-rpi-image.sh"
    local output
    local exit_code
    
    # Run script with provided arguments and capture output
    output=$("$script_path" "$@" 2>&1)
    exit_code=$?
    
    # Store results for BATS to use
    echo "$output"
    return $exit_code
}

# Helper to check if script shows help
shows_help() {
    local output="$1"
    
    # Check for key help indicators
    echo "$output" | grep -q "USAGE:" && \
    echo "$output" | grep -q "REQUIRED OPTIONS:" && \
    echo "$output" | grep -q "OPTIONAL OPTIONS:" && \
    echo "$output" | grep -q "EXAMPLES:"
}

# Helper to check if script lists agents
lists_agents() {
    local output="$1"
    
    echo "$output" | grep -q "Listing registered agents" && \
    echo "$output" | grep -q "Agent ID:"
}

# Helper to check for configuration validation error
shows_validation_error() {
    local output="$1"
    local expected_error="$2"
    
    echo "$output" | grep -q "Configuration validation failed" && \
    echo "$output" | grep -q "$expected_error"
}

# Helper to check if script detects platform correctly
detects_platform() {
    local output="$1"
    local expected_platform="$2"
    
    echo "$output" | grep -q "Detected platform: $expected_platform"
}

# Setup function to reset global variables before each test
setup_test_environment() {
    # Reset any global variables that might persist
    unset CONFIG_OH_VERSION
    unset CONFIG_BASE_IMAGE
    unset CONFIG_OUTPUT_IMAGE
    unset CONFIG_EXCHANGE_URL
    unset CONFIG_EXCHANGE_ORG
    unset CONFIG_EXCHANGE_USER
    unset CONFIG_EXCHANGE_TOKEN
    unset CONFIG_NODE_JSON
    unset CONFIG_WIFI_SSID
    unset CONFIG_WIFI_PASSWORD
    unset CONFIG_WIFI_SECURITY
    
    # Clear log file
    rm -f "${BATS_TEST_DIRNAME}/../build-rpi-image.log"
}

# Teardown function to clean up after tests
cleanup_test_environment() {
    local test_dir="${BATS_TMP_DIR:-/tmp/bats_test}"
    
    if [[ -d "$test_dir" ]]; then
        rm -rf "$test_dir"
    fi
}

# Export variables that BATS might need
export BATS_TEST_DIRNAME="${BATS_TEST_DIRNAME:-$(dirname "${BASH_SOURCE[0]}")}"