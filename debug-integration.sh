#!/bin/bash
# Simple debug script for integration tests
cd /Users/josephpearson/local/rpi-hzn

echo "=== Manual Integration Test Debug ==="

echo "1. Testing help..."
if ./build-rpi-image.sh --help 2>&1 | grep -q "USAGE:"; then
    echo "   Help: PASS"
else
    echo "   Help: FAIL"
fi

echo "2. Testing list agents..."
if ./build-rpi-image.sh --list-agents 2>&1 | grep -q "Agent ID:"; then
    echo "   List Agents: PASS"
else
    echo "   List Agents: FAIL"
fi

echo "3. Testing parameter validation..."
if ./build-rpi-image.sh --oh-version "2.30.0" --base-image "nonexistent.img" 2>&1 | grep -q "Configuration validation failed"; then
    echo "   Parameter Validation: PASS"
else
    echo "   Parameter Validation: FAIL"
fi

echo "=== Basic CLI Tests Complete ==="