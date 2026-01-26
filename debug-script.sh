#!/bin/bash
# Debug the exact issue with integration test
PROJECT_ROOT="/Users/josephpearson/local/rpi-hzn"

echo "=== Debug Integration Test ==="
echo "PROJECT_ROOT: $PROJECT_ROOT"
echo "Working directory: $(pwd)"

# Test individual components
echo "1. Testing help command directly:"
help_result=$("$PROJECT_ROOT/build-rpi-image.sh" --help 2>&1)
echo "   Help exit code: $?"
echo "   Help contains USAGE: $(echo "$help_result" | grep -q "USAGE:" && echo "YES" || echo "NO")"

echo "2. Testing list agents command directly:"
agents_result=$("$PROJECT_ROOT/build-rpi-image.sh" --list-agents 2>&1)
echo "   Agents exit code: $?"
echo "   Agents contains Agent ID: $(echo "$agents_result" | grep -q "Agent ID:" && echo "YES" || echo "NO")"

echo "3. Testing validation command directly:"
validation_result=$("$PROJECT_ROOT/build-rpi-image.sh" --oh-version "2.30.0" --base-image "nonexistent.img" 2>&1)
echo "   Validation exit code: $?"
echo "   Validation contains error: $(echo "$validation_result" | grep -q "Configuration validation failed" && echo "YES" || echo "NO")"

echo "=== Debug Complete ==="