#!/bin/bash
# BATS configuration for this project
# Sets up environment and configuration for running tests

# Set BATS temporary directory
export BATS_TMPDIR="/tmp/bats_test_$$"

# Ensure the test environment is clean
cleanup_on_test_exit() {
    if [[ -n "$BATS_TMPDIR" && -d "$BATS_TMPDIR" ]]; then
        rm -rf "$BATS_TMPDIR"
    fi
}

# Set up cleanup trap
trap cleanup_on_test_exit EXIT

# Create temporary directory
mkdir -p "$BATS_TMPDIR"

# Export common variables
export BATS_TEST_DIRNAME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Suppress debug output during tests unless explicitly enabled
if [[ "${DEBUG_BATS:-}" != "1" ]]; then
    export DEBUG=0
fi

echo "BATS test environment initialized"
echo "BATS_TMPDIR: $BATS_TMPDIR"
echo "BATS_TEST_DIRNAME: $BATS_TEST_DIRNAME"