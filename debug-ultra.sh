#!/bin/bash
# Ultra-simple debug to find the exact issue
cd /Users/josephpearson/local/rpi-hzn/test/integration

PROJECT_ROOT="/Users/josephpearson/local/rpi-hzn"

echo "=== Ultra Debug Test ==="
echo "Current directory: $(pwd)"
echo "PROJECT_ROOT: $PROJECT_ROOT"

echo "Test 1: Help from current directory:"
help_output=$("$PROJECT_ROOT/build-rpi-image.sh" --help 2>&1)
echo "Exit code: $?"
if echo "$help_output" | grep -q "USAGE:"; then
    echo "Help: FOUND USAGE"
else
    echo "Help: NO USAGE"
    echo "Output was:"
    echo "$help_output" | head -5
fi

echo ""
echo "Test 2: Exact same as working basic test:"
if "$PROJECT_ROOT/build-rpi-image.sh" --help 2>&1 | grep -q "USAGE:"; then
    echo "Direct test: PASS"
else
    echo "Direct test: FAIL"
fi