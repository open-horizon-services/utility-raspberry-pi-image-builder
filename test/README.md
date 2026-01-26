# Test Suite for Raspberry Pi Image Builder

This directory contains unit tests for the build-rpi-image.sh script, implemented using the BATS (Bash Automated Testing System) framework.

## Test Organization

```
test/
├── unit/
│   └── test-cli.bats           # Unit tests for command-line interface
├── fixtures/                   # Test data and mock files
├── helpers.bats                # Common test utilities and helper functions
└── setup.bash                 # Test environment configuration
```

## Running Tests

### Prerequisites

1. **Install BATS testing framework**:
   ```bash
   # On macOS with Homebrew
   brew install bats-core
   
   # On Linux (Ubuntu/Debian)
   sudo apt-get install bats
   
   # Or install from source
   git clone https://github.com/bats-core/bats-core.git
   cd bats-core
   ./install.sh /usr/local
   ```

2. **Verify installation**:
   ```bash
   bats --version
   ```

### Running All Tests

```bash
# Run all unit tests
bats test/unit/

# Run tests with verbose output
bats -t test/unit/

# Run tests with debugging
DEBUG_BATS=1 bats test/unit/
```

### Running Specific Tests

```bash
# Run a specific test file
bats test/unit/test-cli.bats

# Run specific test cases by line number
bats --filter "CLI-001" test/unit/test-cli.bats

# Run tests matching a pattern
bats --filter "help" test/unit/test-cli.bats
```

### Test Coverage

The unit tests cover the following command-line interface functionality:

#### Help and Documentation
- **CLI-001**: Test `--help` flag functionality
- **CLI-002**: Test `-h` short flag functionality
- **CLI-003**: Test `--list-agents` flag functionality

#### Parameter Validation
- **CLI-004**: Test validation of missing required parameters
- **CLI-005**: Test validation of missing base image parameter
- **CLI-006**: Test validation of missing output image parameter
- **CLI-007**: Test validation of nonexistent base image file
- **CLI-008**: Test acceptance of all valid required parameters

#### Platform Detection
- **CLI-009**: Test correct platform detection (Linux/macOS)

#### Wi-Fi Configuration
- **CLI-010**: Test acceptance of valid Wi-Fi parameters
- **CLI-011**: Test validation of Wi-Fi SSID without password
- **CLI-012**: Test validation of invalid Wi-Fi security type

#### Exchange Registration
- **CLI-013**: Test acceptance of valid exchange parameters
- **CLI-014**: Test validation of incomplete exchange parameters

#### Custom Configuration
- **CLI-015**: Test validation of nonexistent node.json file
- **CLI-016**: Test acceptance of valid node.json file
- **CLI-017**: Test acceptance of custom mount point

#### Error Handling
- **CLI-018**: Test rejection of unknown arguments

#### Debug and Logging
- **CLI-019**: Test debug logging functionality
- **CLI-020**: Test configuration summary logging with redaction

## Test Data

### Test Images
The tests create minimal disk image files with proper MBR signatures for validation. These are automatically created and cleaned up during test execution.

### Configuration Files
Test configuration files (node.json, etc.) are created dynamically in temporary directories to avoid conflicts with real project files.

## Test Environment

### Isolation
Each test runs in an isolated environment with:
- Temporary directories for test data
- Clean global variable state
- Separate log files
- Automatic cleanup

### Debug Mode
Enable debug output during tests:
```bash
DEBUG_BATS=1 bats test/unit/
```

### Continuous Integration
The tests are designed to run in CI/CD environments and provide:
- Clear pass/fail indicators
- Detailed error messages
- Exit codes for automation
- No external dependencies (except BATS)

## Adding New Tests

When adding new tests:

1. **Follow naming convention**: `TEST-XXX` format
2. **Use helpers**: Leverage functions in `helpers.bats`
3. **Test one thing**: Each test should validate a single behavior
4. **Clean up**: Use `setup()` and `teardown()` functions
5. **Document**: Add clear description of what the test validates

### Test Template

```bash
@test "CLI-XXX: Test description" {
    # Setup test data if needed
    local test_file
    test_file=$(create_test_file "test.txt" "test content")
    
    # Run the test
    run run_script_with_args --argument "$test_file"
    
    # Assert results
    [ "$status" -eq 0 ] || {
        echo "Expected exit code 0, got $status"
        false
    }
    
    echo "$output" | grep -q "Expected text" || {
        echo "Expected text in output"
        echo "Output: $output"
        false
    }
}
```

## Troubleshooting

### Common Issues

1. **"BATS command not found"**: Install BATS framework
2. **Permission denied**: Ensure test files are executable (`chmod +x`)
3. **Test data not found**: Check `create_test_image` helper function
4. **Global variable conflicts**: Use `setup_test_environment()` helper

### Debugging Failed Tests

Run with debug mode and verbose output:
```bash
DEBUG_BATS=1 bats -t test/unit/test-cli.bats
```

This will show:
- Test environment setup
- Temporary file locations
- Script output
- Detailed error messages