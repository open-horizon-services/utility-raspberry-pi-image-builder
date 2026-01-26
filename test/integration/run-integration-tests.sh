#!/bin/bash
# Integration Test Suite for Raspberry Pi Image Builder
# Validates end-to-end functionality of complete image creation workflow

set -euo pipefail

# Test environment configuration
INTEGRATION_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$INTEGRATION_TEST_DIR")"
TEST_DATA_DIR="${INTEGRATION_TEST_DIR}/test_data"
RESULTS_DIR="${INTEGRATION_TEST_DIR}/results"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
TEST_IMAGE_SIZE="100M"
TEST_OH_VERSION="2.30.0"

# Initialize test environment
init_test_environment() {
    echo -e "${BLUE}=== Initializing Integration Test Environment ===${NC}"
    
    # Create test directories
    mkdir -p "$TEST_DATA_DIR" "$RESULTS_DIR"
    
    # Clean up any previous test artifacts
    rm -f "$TEST_DATA_DIR"/*.img
    rm -f "$RESULTS_DIR"/*.log
    
    echo "Test directories created:"
    echo "  - Test Data: $TEST_DATA_DIR"
    echo "  - Results: $RESULTS_DIR"
    echo ""
}

# Create test Raspberry Pi image file
create_test_image() {
    local image_name="$1"
    local image_path="${TEST_DATA_DIR}/${image_name}.img"
    
    echo -e "${BLUE}Creating test image: $image_name${NC}"
    
    # Create a minimal disk image with proper structure
    {
        # Create MBR with basic partition table
        # First 446 bytes: partition table area (zeros)
        dd if=/dev/zero bs=446 count=1 2>/dev/null
        # Partition 1: FAT32 boot partition (type 0x0C)
        printf '\x80\x01\x01\x00\x83\xFE\xFF\xFF\x00\x00\x00\x08\x00\x00\x00\x80\x01\x01\x00'
        # Partition 2: Linux root partition (type 0x83) 
        printf '\x00\x08\x00\x00\x83\xFE\xFF\xFF\x00\x00\x00\x20\x00\x00\x00\x00\x08\x20\x00'
        # MBR signature
        printf '\x55\xAA'
        # Add some data for partition 1 (boot partition, ~10MB)
        dd if=/dev/zero bs=10M count=1 2>/dev/null
        # Add more data for partition 2 (root partition, ~90MB)
        dd if=/dev/zero bs=90M count=1 2>/dev/null
    } > "$image_path"
    
    # Verify image was created
    if [[ -f "$image_path" && -s "$image_path" ]]; then
        local size=$(ls -lh "$image_path" | awk '{print $5}')
        echo -e "${GREEN}✓ Test image created: $image_name ($size)${NC}"
        echo "$image_path"
    else
        echo -e "${RED}✗ Failed to create test image: $image_name${NC}"
        return 1
    fi
}

# Run integration test with specific configuration
run_integration_test() {
    local test_name="$1"
    local image_name="$2"
    shift 2
    local extra_args=("$@")
    
    echo -e "${BLUE}=== Integration Test: $test_name ===${NC}"
    
    # Create test image
    local test_image
    test_image=$(create_test_image "$image_name")
    
    # Prepare test command
    local output_image="${RESULTS_DIR}/${image_name}-output.img"
    local log_file="${RESULTS_DIR}/${test_name}.log"
    
    # Build command arguments
    local cmd=(
        "$PROJECT_ROOT/build-rpi-image.sh"
        --oh-version "$TEST_OH_VERSION"
        --base-image "$test_image"
        --output-image "$output_image"
        "${extra_args[@]}"
    )
    
    echo "Running command: ${cmd[*]}"
    echo "Log file: $log_file"
    echo ""
    
    # Run the test with timeout and capture results
    local start_time=$(date +%s)
    local exit_code=0
    local output=""
    
    # Execute with timeout and capture output
    if timeout 300 "${cmd[@]}" > "$log_file" 2>&1; then
        exit_code=0
    else
        exit_code=$?
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Analyze results
    echo -e "${BLUE}=== Test Results: $test_name ===${NC}"
    echo "Exit Code: $exit_code"
    echo "Duration: ${duration}s"
    echo "Log File: $log_file"
    echo ""
    
    # Check for expected outcomes
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}✓ Test PASSED: $test_name${NC}"
        if [[ -f "$output_image" ]]; then
            local output_size=$(ls -lh "$output_image" 2>/dev/null | awk '{print $5}')
            echo "  Output Image: Created ($output_size)"
        fi
    else
        echo -e "${RED}✗ Test FAILED: $test_name${NC}"
        echo "  Last 10 lines of log:"
        tail -10 "$log_file" 2>/dev/null | sed 's/^/    /'
    fi
    
    echo ""
    
    return $exit_code
}

# Test basic functionality (should fail at compatibility check but show complete pipeline)
test_basic_functionality() {
    echo -e "${BLUE}=== Testing Basic CLI Functionality ===${NC}"
    
    local failed_count=0
    
    # Test 1: Help functionality
    echo -n "Testing help... "
    local help_output
    help_output=$("$PROJECT_ROOT/build-rpi-image.sh" --help 2>&1)
    if echo "$help_output" | grep -q "USAGE:"; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC}"
        ((failed_count++))
    fi
    
    # Test 2: List agents
    echo -n "Testing list agents... "
    local agents_output
    agents_output=$("$PROJECT_ROOT/build-rpi-image.sh" --list-agents 2>&1)
    if echo "$agents_output" | grep -q "Agent ID:"; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC}"
        ((failed_count++))
    fi
    
    # Test 3: Parameter validation
    echo -n "Testing parameter validation... "
    local validation_output
    validation_output=$("$PROJECT_ROOT/build-rpi-image.sh" --oh-version "2.30.0" --base-image "nonexistent.img" 2>&1)
    if echo "$validation_output" | grep -q "Configuration validation failed"; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC}"
        ((failed_count++))
    fi
    
    echo ""
    echo "Results: $((3 - failed_count))/3 tests passed"
    
    if [[ $failed_count -eq 0 ]]; then
        echo -e "${GREEN}✓ Basic CLI functionality verified${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}✗ Basic CLI functionality tests failed${NC}"
        echo ""
        return 1
    fi
}

# Main integration test suite
main() {
    echo -e "${GREEN}=== Raspberry Pi Image Builder Integration Test Suite ===${NC}"
    echo "Testing complete image creation workflow..."
    echo ""
    
    # Initialize test environment
    init_test_environment
    
    # Test basic functionality first
    if ! test_basic_functionality; then
        echo -e "${RED}Basic functionality tests failed. Aborting integration tests.${NC}"
        exit 1
    fi
    
    # Integration Test 1: Minimal configuration
    echo -e "${BLUE}=== Integration Test 1: Minimal Configuration ===${NC}"
    run_integration_test "Minimal-Config" "minimal-basic" --debug
    
    # Integration Test 2: Wi-Fi configuration
    echo -e "${BLUE}=== Integration Test 2: Wi-Fi Configuration ===${NC}"
    run_integration_test "WiFi-Config" "test-wifi" \
        --wifi-ssid "TestNetwork" \
        --wifi-password "TestPassword123" \
        --wifi-security "WPA2" \
        --debug
    
    # Integration Test 3: Exchange registration
    echo -e "${BLUE}=== Integration Test 3: Exchange Registration ===${NC}"
    run_integration_test "Exchange-Config" "test-exchange" \
        --exchange-url "https://exchange.example.com" \
        --exchange-org "testorg" \
        --exchange-user "testuser" \
        --exchange-token "testtoken123" \
        --debug
    
    # Integration Test 4: Full configuration
    echo -e "${BLUE}=== Integration Test 4: Full Configuration ===${NC}"
    run_integration_test "Full-Config" "test-full" \
        --wifi-ssid "FullNetwork" \
        --wifi-password "FullPassword123" \
        --wifi-security "WPA2" \
        --exchange-url "https://exchange.example.com" \
        --exchange-org "fullorg" \
        --exchange-user "fulluser" \
        --exchange-token "fulltoken123" \
        --debug
    
    # Generate test summary
    echo -e "${GREEN}=== Integration Test Summary ===${NC}"
    echo "Test logs and results saved to: $RESULTS_DIR"
    echo ""
    echo "Test Data Directory: $TEST_DATA_DIR"
    echo "Results Directory: $RESULTS_DIR"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo "1. Review test logs in $RESULTS_DIR"
    echo "2. Check for any failed tests"
    echo "3. Verify error handling and cleanup"
    echo "4. Run Task 12: Final checkpoint validation"
}

# Execute main function if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi