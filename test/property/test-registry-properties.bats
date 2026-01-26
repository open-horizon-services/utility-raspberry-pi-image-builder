#!/usr/bin/env bats
# Property-based tests for registry behavior
# Feature: raspberry-pi-image-builder, Property 15+: Registry invariants

load "../helpers.bats"

setup() {
    setup_test_environment
}

teardown() {
    cleanup_test_environment
}

# Helper: create a minimal registry entry
create_sample_entry() {
    local agent_id="$1"
    cat << EOF

## Agent Configuration: $agent_id

- **Created**: 2026-01-26T00:00:00Z
- **Open Horizon Version**: 2.30.0
- **Exchange URL**: https://exchange.example.com (org: org)
- **Node JSON**: default
- **Wi-Fi SSID**: none
- **Base Image**: base.img
- **Output Image**: output.img
- **Status**: created

EOF
}

@test "Property 15: Registry entries are appended, not overwritten" {
    load_script

    for ((i=1; i<=100; i++)); do
        local registry_file="${BATS_TMPDIR:-/tmp/bats_test}/REGISTRY.md"
        local first_id="agent-${i}-a"
        local second_id="agent-${i}-b"

        create_agents_file_header > "$registry_file"
        append_to_agents_file "$registry_file" "$(create_sample_entry "$first_id")"
        append_to_agents_file "$registry_file" "$(create_sample_entry "$second_id")"

        grep -q "Agent Configuration: $first_id" "$registry_file"
        grep -q "Agent Configuration: $second_id" "$registry_file"
    done
}

@test "Property 16: Registry validation passes with correct header" {
    load_script

    for ((i=1; i<=100; i++)); do
        local registry_file="${BATS_TMPDIR:-/tmp/bats_test}/REGISTRY-${i}.md"
        create_agents_file_header > "$registry_file"
        validate_agents_file "$registry_file"
    done
}
