#!/usr/bin/env bats
# Property-based tests for core modules
# Feature: raspberry-pi-image-builder, Property 1+: Core module invariants

load "../helpers.bats"

setup() {
    setup_test_environment
}

teardown() {
    cleanup_test_environment
}

# Helper: check if array contains value
array_contains() {
    local needle="$1"
    shift
    local item
    for item in "$@"; do
        if [[ "$item" == "$needle" ]]; then
            return 0
        fi
    done
    return 1
}

# Helper: generate random alphanumeric string of length N
random_string() {
    local length="$1"
    LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$length"
}

# Helper: create a minimal image with MBR signature and size in bytes
create_mbr_image() {
    local image_path="$1"
    local size_bytes="$2"

    dd if=/dev/zero bs=1 count="$size_bytes" 2>/dev/null > "$image_path"
    printf '\x55\xAA' | dd of="$image_path" bs=1 seek=510 count=2 conv=notrunc 2>/dev/null
}

@test "Property 1: Platform tool selection contains required tools" {
    source "${BATS_TEST_DIRNAME}/../lib/platform-detect.sh"

    for ((i=1; i<=100; i++)); do
        detect_platform
        select_platform_tools

        if [[ "$DETECTED_PLATFORM" == "linux" ]]; then
            array_contains "mount" "${PLATFORM_TOOLS[@]}" || false
            array_contains "umount" "${PLATFORM_TOOLS[@]}" || false
        elif [[ "$DETECTED_PLATFORM" == "macos" ]]; then
            array_contains "hdiutil" "${PLATFORM_TOOLS[@]}" || false
            array_contains "diskutil" "${PLATFORM_TOOLS[@]}" || false
        fi
    done
}

@test "Property 2: Wi-Fi validation accepts valid WPA2/WPA3 credentials" {
    source "${BATS_TEST_DIRNAME}/../lib/network-config.sh"

    for ((i=1; i<=100; i++)); do
        local ssid_length=$((RANDOM % 32 + 1))
        local password_length=$((RANDOM % 56 + 8))
        local ssid
        local password
        local security

        ssid=$(random_string "$ssid_length")
        password=$(random_string "$password_length")
        security=$([[ $((i % 2)) -eq 0 ]] && echo "WPA2" || echo "WPA3")

        validate_wifi_configuration "$ssid" "$password" "$security"
    done
}

@test "Property 3: Wi-Fi validation rejects invalid credentials" {
    source "${BATS_TEST_DIRNAME}/../lib/network-config.sh"

    for ((i=1; i<=100; i++)); do
        local ssid
        local password

        ssid=""
        password=$(random_string 8)
        ! validate_wifi_configuration "$ssid" "$password" "WPA2"

        ssid=$(random_string 4)
        password=$(random_string 7)
        ! validate_wifi_configuration "$ssid" "$password" "WPA2"

        ssid=$(random_string 4)
        password=$(random_string 64)
        ! validate_wifi_configuration "$ssid" "$password" "WPA3"
    done
}

@test "Property 4: Registry entry includes required fields" {
    load_script

    for ((i=1; i<=100; i++)); do
        local agent_id="agent-${i}"
        local created
        local oh_version="2.${i}.0"
        local base_image="/tmp/base-${i}.img"
        local output_image="/tmp/output-${i}.img"
        local exchange_url="https://exchange.example.com"
        local exchange_org="org-${i}"
        local node_json="/tmp/node-${i}.json"
        local wifi_ssid="ssid-${i}"

        created=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        local entry
        entry=$(create_registry_entry "$agent_id" "$created" "$oh_version" "$base_image" "$output_image" "$exchange_url" "$exchange_org" "$node_json" "$wifi_ssid")

        [[ "$entry" == *"## Agent Configuration: $agent_id"* ]]
        [[ "$entry" == *"Open Horizon Version"* ]]
        [[ "$entry" == *"Exchange URL"* ]]
        [[ "$entry" == *"Node JSON"* ]]
        [[ "$entry" == *"Wi-Fi SSID"* ]]
        [[ "$entry" == *"Base Image"* ]]
        [[ "$entry" == *"Output Image"* ]]
    done
}

@test "Property 5: MBR images pass Raspberry Pi Imager compatibility checks" {
    source "${BATS_TEST_DIRNAME}/../lib/image-verify.sh"

    for ((i=1; i<=100; i++)); do
        local image_path="${BATS_TMPDIR:-/tmp/bats_test}/mbr-${i}.img"
        local size_bytes=$((512 * (RANDOM % 20 + 4)))

        create_mbr_image "$image_path" "$size_bytes"
        verify_rpi_imager_compatibility "$image_path"
    done
}
