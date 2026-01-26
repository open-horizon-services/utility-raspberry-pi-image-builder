#!/usr/bin/env bats
# Property-based tests for validation behavior
# Feature: raspberry-pi-image-builder, Property 21+: Validation invariants

load "../helpers.bats"

setup() {
    setup_test_environment
}

teardown() {
    cleanup_test_environment
}

# Helper: run validation in isolation
run_validation() {
    local oh_version="$1"
    local base_image="$2"
    local output_image="$3"
    local wifi_ssid="$4"
    local wifi_password="$5"
    local wifi_security="$6"

    CONFIG_OH_VERSION="$oh_version"
    CONFIG_BASE_IMAGE="$base_image"
    CONFIG_OUTPUT_IMAGE="$output_image"
    CONFIG_WIFI_SSID="$wifi_ssid"
    CONFIG_WIFI_PASSWORD="$wifi_password"
    CONFIG_WIFI_SECURITY="$wifi_security"

    validate_configuration
}

@test "Property 21: Missing required params fail validation" {
    load_script

    for ((i=1; i<=100; i++)); do
        local output_image="/tmp/output-${i}.img"
        ! run_validation "" "" "$output_image" "" "" "WPA2"
    done
}

@test "Property 22: Nonexistent base images fail validation" {
    load_script

    for ((i=1; i<=100; i++)); do
        local base_image="/tmp/does-not-exist-${i}.img"
        local output_image="/tmp/output-${i}.img"
        ! run_validation "2.30.0" "$base_image" "$output_image" "" "" "WPA2"
    done
}

@test "Property 23: Invalid Wi-Fi security fails validation" {
    load_script

    for ((i=1; i<=100; i++)); do
        local base_image
        base_image=$(create_test_image "base-${i}.img" "1M")
        local output_image="/tmp/output-${i}.img"
        ! run_validation "2.30.0" "$base_image" "$output_image" "ssid${i}" "password123" "WEP"
    done
}
