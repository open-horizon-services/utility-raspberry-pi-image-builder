#!/bin/bash
# Simplified integration test focused on basic functionality
set -euo pipefail

PROJECT_ROOT="/Users/josephpearson/local/rpi-hzn"
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "=== Testing Basic CLI Functionality ==="

test_basic_functionality() {
    # Test 1: Help functionality
    echo -n "Testing help... "
    if "$PROJECT_ROOT/build-rpi-image.sh" --help 2>&1 | grep -q "USAGE:"; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC}"
        return 1
    fi
    
    # Test 2: List agents
    echo -n "Testing list agents... "
    local agents_output
    agents_output=$("$PROJECT_ROOT/build-rpi-image.sh" --list-agents 2>&1)
    if echo "$agents_output" | grep -q "Agent ID:"; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC}"
        echo "  Debug: Output was: $agents_output"
        return 1
    fi
    
    # Test 3: Parameter validation
    echo -n "Testing parameter validation... "
    local validation_output
    validation_output=$("$PROJECT_ROOT/build-rpi-image.sh" --oh-version "2.30.0" --base-image "nonexistent.img" 2>&1)
    if echo "$validation_output" | grep -q "Configuration validation failed"; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC}"
        echo "  Debug: Output was: $validation_output"
        return 1
    fi
    
    echo -e "${GREEN}✓ Basic CLI functionality verified${NC}"
    return 0
}

# Run the test
if test_basic_functionality; then
    echo -e "${GREEN}All basic functionality tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Basic functionality tests failed!${NC}"
    exit 1
fi