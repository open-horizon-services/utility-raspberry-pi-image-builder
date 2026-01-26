#!/usr/bin/env bats
# Property-based tests for exchange configuration
# Feature: raspberry-pi-image-builder, Property 7+: Exchange invariants

load "../helpers.bats"

setup() {
    setup_test_environment
}

teardown() {
    cleanup_test_environment
}

# Helper: generate random alphanumeric string
random_string() {
    local length="$1"
    LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$length"
}

@test "Property 7: Exchange config is required for registration" {
    load_script

    for ((i=1; i<=100; i++)); do
        CONFIG_EXCHANGE_URL=""
        CONFIG_EXCHANGE_ORG=""
        CONFIG_EXCHANGE_USER=""
        CONFIG_EXCHANGE_TOKEN=""
        ! is_exchange_registration_requested

        CONFIG_EXCHANGE_URL="https://exchange.example.com"
        CONFIG_EXCHANGE_ORG="org-${i}"
        CONFIG_EXCHANGE_USER="user-${i}"
        CONFIG_EXCHANGE_TOKEN="token-${i}"
        is_exchange_registration_requested
    done
}

@test "Property 8: Registration config string preserves inputs" {
    source "${BATS_TEST_DIRNAME}/../lib/horizon-install.sh"

    for ((i=1; i<=100; i++)); do
        local exchange_url="https://exchange-${i}.example.com"
        local exchange_org="org-${i}"
        local exchange_user="user-${i}"
        local exchange_token
        exchange_token=$(random_string 12)

        local config
        config=$(create_registration_config "$exchange_url" "$exchange_org" "$exchange_user" "$exchange_token")

        [[ "$config" == "${exchange_url}|${exchange_org}|${exchange_user}|${exchange_token}" ]]
    done
}

@test "Property 9: Invalid exchange URL format is rejected" {
    source "${BATS_TEST_DIRNAME}/../lib/horizon-install.sh"

    for ((i=1; i<=100; i++)); do
        local bad_url="exchange-${i}.example.com"
        ! validate_exchange_connectivity "$bad_url"
    done
}
