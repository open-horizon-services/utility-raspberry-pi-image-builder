#!/usr/bin/env bats
# Unit tests for command-line interface
# Tests help output, argument parsing, and error conditions
# Feature: raspberry-pi-image-builder, Property 19: Parameter acceptance and handling

setup_file() {
    export BATS_TEST_DIRNAME="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    export PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
}

load "../helpers.bats"

setup() {
    setup_test_environment
}

teardown() {
    cleanup_test_environment
}

@test "CLI-001: Script shows help when --help is provided" {
    # Test basic help functionality
    run run_script_with_args --help
    
    [ "$status" -eq 0 ] || {
        echo "Expected exit code 0, got $status"
        echo "Output: $output"
        false
    }
    
    shows_help "$output" || {
        echo "Help output doesn't contain expected sections"
        echo "Output: $output"
        false
    }
}

@test "CLI-002: Script shows help when -h is provided" {
    # Test short help option
    run run_script_with_args -h
    
    [ "$status" -eq 0 ] || {
        echo "Expected exit code 0, got $status"
        false
    }
    
    shows_help "$output" || {
        echo "Help output doesn't contain expected sections"
        false
    }
}

@test "CLI-003: Script lists agents when --list-agents is provided" {
    # Test list agents functionality
    run run_script_with_args --list-agents
    
    [ "$status" -eq 0 ] || {
        echo "Expected exit code 0, got $status"
        false
    }
    
    lists_agents "$output" || {
        echo "Output doesn't contain agent listing"
        echo "Output: $output"
        false
    }
}

@test "CLI-004: Script validates missing required parameters" {
    # Test validation when no parameters are provided
    run run_script_with_args
    
    [ "$status" -ne 0 ] || {
        echo "Expected non-zero exit code, got $status"
        false
    }
    
    shows_validation_error "$output" "Open Horizon version is required" || {
        echo "Expected version validation error"
        echo "Output: $output"
        false
    }
}

@test "CLI-005: Script validates missing base image parameter" {
    # Test validation when base image is missing
    run run_script_with_args --oh-version "2.30.0"
    
    [ "$status" -ne 0 ] || {
        echo "Expected non-zero exit code, got $status"
        false
    }
    
    shows_validation_error "$output" "Base image path is required" || {
        echo "Expected base image validation error"
        echo "Output: $output"
        false
    }
}

@test "CLI-006: Script validates missing output image parameter" {
    # Test validation when output image is missing
    run run_script_with_args --oh-version "2.30.0" --base-image "test.img"
    
    [ "$status" -ne 0 ] || {
        echo "Expected non-zero exit code, got $status"
        false
    }
    
    shows_validation_error "$output" "Output image path is required" || {
        echo "Expected output image validation error"
        echo "Output: $output"
        false
    }
}

@test "CLI-007: Script validates nonexistent base image" {
    # Test validation when base image doesn't exist
    run run_script_with_args \
        --oh-version "2.30.0" \
        --base-image "nonexistent.img" \
        --output-image "output.img"
    
    [ "$status" -ne 0 ] || {
        echo "Expected non-zero exit code, got $status"
        false
    }
    
    shows_validation_error "$output" "Base image file does not exist" || {
        echo "Expected file existence error"
        echo "Output: $output"
        false
    }
}

@test "CLI-008: Script accepts valid required parameters" {
    # Test acceptance of valid parameters (but should fail at image compatibility check)
    local test_image
    test_image=$(create_test_image "valid-test.img")
    
    run run_script_with_args \
        --oh-version "2.30.0" \
        --base-image "$test_image" \
        --output-image "output.img"
    
    # Should fail at image format compatibility, not parameter validation
    [ "$status" -ne 0 ] || {
        echo "Expected non-zero exit code (image compatibility check should fail)"
        false
    }
    
    # Should NOT show parameter validation errors
    ! shows_validation_error "$output" "required" || {
        echo "Unexpected parameter validation error"
        echo "Output: $output"
        false
    }
}

@test "CLI-009: Script detects platform correctly" {
    # Test platform detection
    local test_image
    test_image=$(create_test_image "platform-test.img")
    
    run run_script_with_args \
        --oh-version "2.30.0" \
        --base-image "$test_image" \
        --output-image "output.img" \
        --debug
    
    # Should fail at some point, but after platform detection
    local platform
    platform=$(uname -s)
    case "$platform" in
        Linux*)  expected_platform="linux" ;;
        Darwin*) expected_platform="macos" ;;
        *)       expected_platform="unknown" ;;
    esac
    
    detects_platform "$output" "$expected_platform" || {
        echo "Expected to detect platform: $expected_platform"
        echo "Output: $output"
        false
    }
}

@test "CLI-010: Script accepts optional Wi-Fi parameters" {
    # Test Wi-Fi parameter acceptance
    local test_image
    test_image=$(create_test_image "wifi-test.img")
    
    run run_script_with_args \
        --oh-version "2.30.0" \
        --base-image "$test_image" \
        --output-image "output.img" \
        --wifi-ssid "TestNetwork" \
        --wifi-password "TestPassword123" \
        --wifi-security "WPA2"
    
    # Should fail at image compatibility, but accept Wi-Fi parameters
    [ "$status" -ne 0 ] || {
        echo "Expected non-zero exit code"
        false
    }
    
    # Should NOT show Wi-Fi validation errors
    ! shows_validation_error "$output" "Wi-Fi" || {
        echo "Unexpected Wi-Fi validation error"
        echo "Output: $output"
        false
    }
}

@test "CLI-011: Script validates Wi-Fi SSID without password" {
    # Test Wi-Fi validation when password is missing
    local test_image
    test_image=$(create_test_image "wifi-validation-test.img")
    
    run run_script_with_args \
        --oh-version "2.30.0" \
        --base-image "$test_image" \
        --output-image "output.img" \
        --wifi-ssid "TestNetwork"
    
    [ "$status" -ne 0 ] || {
        echo "Expected non-zero exit code"
        false
    }
    
    shows_validation_error "$output" "Wi-Fi SSID specified but password is missing" || {
        echo "Expected Wi-Fi password validation error"
        echo "Output: $output"
        false
    }
}

@test "CLI-012: Script validates invalid Wi-Fi security type" {
    # Test Wi-Fi security type validation
    local test_image
    test_image=$(create_test_image "wifi-security-test.img")
    
    run run_script_with_args \
        --oh-version "2.30.0" \
        --base-image "$test_image" \
        --output-image "output.img" \
        --wifi-ssid "TestNetwork" \
        --wifi-password "TestPassword123" \
        --wifi-security "INVALID"
    
    [ "$status" -ne 0 ] || {
        echo "Expected non-zero exit code"
        false
    }
    
    shows_validation_error "$output" "Invalid Wi-Fi security type" || {
        echo "Expected Wi-Fi security validation error"
        echo "Output: $output"
        false
    }
}

@test "CLI-013: Script accepts optional exchange parameters" {
    # Test exchange parameter acceptance
    local test_image
    test_image=$(create_test_image "exchange-test.img")
    
    run run_script_with_args \
        --oh-version "2.30.0" \
        --base-image "$test_image" \
        --output-image "output.img" \
        --exchange-url "https://exchange.example.com" \
        --exchange-org "myorg" \
        --exchange-user "myuser" \
        --exchange-token "mytoken"
    
    # Should fail at image compatibility, but accept exchange parameters
    [ "$status" -ne 0 ] || {
        echo "Expected non-zero exit code"
        false
    }
    
    # Should NOT show exchange validation errors
    ! shows_validation_error "$output" "Exchange" || {
        echo "Unexpected exchange validation error"
        echo "Output: $output"
        false
    }
}

@test "CLI-014: Script validates incomplete exchange parameters" {
    # Test exchange validation when some parameters are missing
    local test_image
    test_image=$(create_test_image "exchange-incomplete-test.img")
    
    run run_script_with_args \
        --oh-version "2.30.0" \
        --base-image "$test_image" \
        --output-image "output.img" \
        --exchange-url "https://exchange.example.com" \
        --exchange-org "myorg"
    
    [ "$status" -ne 0 ] || {
        echo "Expected non-zero exit code"
        false
    }
    
    shows_validation_error "$output" "Exchange URL specified but missing organization, user, or token" || {
        echo "Expected exchange validation error"
        echo "Output: $output"
        false
    }
}

@test "CLI-015: Script validates custom node.json file existence" {
    # Test node.json validation when file doesn't exist
    local test_image
    test_image=$(create_test_image "nodejson-test.img")
    
    run run_script_with_args \
        --oh-version "2.30.0" \
        --base-image "$test_image" \
        --output-image "output.img" \
        --node-json "nonexistent-node.json"
    
    [ "$status" -ne 0 ] || {
        echo "Expected non-zero exit code"
        false
    }
    
    shows_validation_error "$output" "Custom node.json file does not exist" || {
        echo "Expected node.json validation error"
        echo "Output: $output"
        false
    }
}

@test "CLI-016: Script accepts valid custom node.json file" {
    # Test acceptance of existing node.json file
    local test_image
    local node_json
    test_image=$(create_test_image "nodejson-valid-test.img")
    node_json=$(create_test_file "test-node.json" '{"id": "test-node", "pattern": "test-pattern"}')
    
    run run_script_with_args \
        --oh-version "2.30.0" \
        --base-image "$test_image" \
        --output-image "output.img" \
        --node-json "$node_json"
    
    # Should fail at image compatibility, but accept node.json parameter
    [ "$status" -ne 0 ] || {
        echo "Expected non-zero exit code"
        false
    }
    
    # Should NOT show node.json validation errors
    ! shows_validation_error "$output" "node.json" || {
        echo "Unexpected node.json validation error"
        echo "Output: $output"
        false
    }
}

@test "CLI-017: Script accepts custom mount point parameter" {
    # Test custom mount point parameter
    local test_image
    test_image=$(create_test_image "mountpoint-test.img")
    
    run run_script_with_args \
        --oh-version "2.30.0" \
        --base-image "$test_image" \
        --output-image "output.img" \
        --mount-point "/tmp/custom_mount"
    
    # Should fail at image compatibility, but accept mount point parameter
    [ "$status" -ne 0 ] || {
        echo "Expected non-zero exit code"
        false
    }
    
    # Should NOT show mount point validation errors
    ! shows_validation_error "$output" "mount-point" || {
        echo "Unexpected mount point validation error"
        echo "Output: $output"
        false
    }
}

@test "CLI-018: Script rejects unknown arguments" {
    # Test rejection of unknown arguments
    run run_script_with_args --unknown-argument
    
    [ "$status" -ne 0 ] || {
        echo "Expected non-zero exit code"
        false
    }
    
    echo "$output" | grep -q "Unknown argument" || {
        echo "Expected unknown argument error"
        echo "Output: $output"
        false
    }
}

@test "CLI-019: Script enables debug logging with --debug flag" {
    # Test debug flag functionality
    local test_image
    test_image=$(create_test_image "debug-test.img")
    
    run run_script_with_args \
        --oh-version "2.30.0" \
        --base-image "$test_image" \
        --output-image "output.img" \
        --debug
    
    # Should fail at image compatibility, but have debug output
    [ "$status" -ne 0 ] || {
        echo "Expected non-zero exit code"
        false
    }
    
    # Check for debug output
    echo "$output" | grep -q "DEBUG:" || {
        echo "Expected debug output"
        echo "Output: $output"
        false
    }
}

@test "CLI-020: Script logs configuration summary when valid parameters provided" {
    # Test configuration summary logging
    local test_image
    test_image=$(create_test_image "config-summary-test.img")
    
    run run_script_with_args \
        --oh-version "2.31.0" \
        --base-image "$test_image" \
        --output-image "test-output.img" \
        --wifi-ssid "TestNetwork" \
        --wifi-password "TestPassword123" \
        --exchange-url "https://exchange.example.com" \
        --exchange-org "testorg" \
        --exchange-user "testuser" \
        --exchange-token "testtoken"
    
    # Should fail at image compatibility, but log configuration first
    [ "$status" -ne 0 ] || {
        echo "Expected non-zero exit code"
        false
    }
    
    # Check for configuration summary sections
    echo "$output" | grep -q "=== Configuration Summary ===" || {
        echo "Expected configuration summary"
        echo "Output: $output"
        false
    }
    
    echo "$output" | grep -q "Open Horizon Version: 2.31.0" || {
        echo "Expected version in summary"
        echo "Output: $output"
        false
    }
    
    echo "$output" | grep -q "Wi-Fi SSID: TestNetwork" || {
        echo "Expected Wi-Fi SSID in summary"
        echo "Output: $output"
        false
    }
    
    echo "$output" | grep -q "Exchange URL: https://exchange.example.com" || {
        echo "Expected exchange URL in summary"
        echo "Output: $output"
        false
    }
    
    echo "$output" | grep -q "\[REDACTED\]" || {
        echo "Expected redacted sensitive information"
        echo "Output: $output"
        false
    }
}