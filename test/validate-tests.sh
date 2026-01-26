#!/bin/bash
# Simple test runner for validating CLI unit tests without BATS
# This script can be used to check if tests are properly structured

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$TEST_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== CLI Unit Tests Validator ===${NC}"
echo "Validating test structure and basic functionality..."

# Test 1: Check if main script exists and is executable
echo -n "Checking main script... "
if [[ -f "$PROJECT_ROOT/build-rpi-image.sh" && -x "$PROJECT_ROOT/build-rpi-image.sh" ]]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    exit 1
fi

# Test 2: Check if test files exist
echo -n "Checking test files... "
if [[ -f "$TEST_DIR/unit/test-cli.bats" && -f "$TEST_DIR/helpers.bats" ]]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    exit 1
fi

# Test 3: Check help functionality
echo -n "Testing help functionality... "
if "$PROJECT_ROOT/build-rpi-image.sh" --help 2>/dev/null | grep -q "USAGE:"; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    exit 1
fi

# Test 4: Check list agents functionality  
echo -n "Testing list agents functionality... "
output=$("$PROJECT_ROOT/build-rpi-image.sh" --list-agents 2>&1)
if echo "$output" | grep -q "Agent ID:"; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    echo "Debug: Output was: $output"
    exit 1
fi

# Test 5: Check parameter validation
echo -n "Testing parameter validation... "
output=$("$PROJECT_ROOT/build-rpi-image.sh" --oh-version "2.30.0" --base-image "nonexistent.img" 2>&1 || true)
if echo "$output" | grep -q "Configuration validation failed"; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    echo "Debug: Output was: $output"
    exit 1
fi

# Test 6: Check test structure
echo -n "Checking test structure... "
test_count=$(grep -c "@test " "$TEST_DIR/unit/test-cli.bats" || echo "0")
if [[ $test_count -ge 15 ]]; then
    echo -e "${GREEN}PASS${NC} ($test_count tests found)"
else
    echo -e "${RED}FAIL${NC} ($test_count tests found, expected at least 15)"
    exit 1
fi

# Test 7: Check helper functions
echo -n "Checking helper functions... "
helper_count=$(grep -c "^[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*(" "$TEST_DIR/helpers.bats" || echo "0")
if [[ $helper_count -ge 10 ]]; then
    echo -e "${GREEN}PASS${NC} ($helper_count helpers found)"
else
    echo -e "${RED}FAIL${NC} ($helper_count helpers found, expected at least 10)"
    exit 1
fi

# Test 8: Check test documentation
echo -n "Checking test documentation... "
if [[ -f "$TEST_DIR/README.md" && -s "$TEST_DIR/README.md" ]]; then
    doc_size=$(wc -l < "$TEST_DIR/README.md")
    if [[ $doc_size -ge 50 ]]; then
        echo -e "${GREEN}PASS${NC} ($doc_size lines of documentation)"
    else
        echo -e "${YELLOW}WARN${NC} (documentation exists but is brief: $doc_size lines)"
    fi
else
    echo -e "${RED}FAIL${NC} (missing documentation)"
    exit 1
fi

echo -e "${GREEN}=== All Basic Checks Passed ===${NC}"
echo ""
echo "Test Structure Summary:"
echo "  - Main Script: ✓"
echo "  - Unit Tests: ✓ ($test_count test cases)"
echo "  - Helper Functions: ✓ ($helper_count helpers)"
echo "  - Documentation: ✓"
echo ""
echo "Next Steps:"
echo "1. Install BATS framework: brew install bats-core"
echo "2. Run full test suite: bats test/unit/"
echo "3. Run with debugging: DEBUG_BATS=1 bats -t test/unit/"
echo ""
echo -e "${YELLOW}Note: Install BATS for comprehensive testing of all 20 test cases${NC}"