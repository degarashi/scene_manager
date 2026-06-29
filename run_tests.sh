#!/bin/bash

# Configuration
GODOT_BIN=${GODOT_BIN:-/opt/godot}
GDUNIT_RUNNER="./addons/gdUnit4/runtest.sh"

# Check if Godot binary exists
if [ ! -f "$GODOT_BIN" ]; then
    echo "Error: Godot binary not found at $GODOT_BIN"
    echo "Please set the GODOT_BIN environment variable or edit this script."
    exit 1
fi

# Check if GdUnit4 runner exists
if [ ! -f "$GDUNIT_RUNNER" ]; then
    echo "Error: GdUnit4 runner not found at $GDUNIT_RUNNER"
    exit 1
fi

echo "--------------------------------------------------"
echo "Running Scene Manager Test Suite"
echo "Godot: $GODOT_BIN"
echo "--------------------------------------------------"

# Export GODOT_BIN for the gdUnit4 runner
export GODOT_BIN

# Run all tests in the tests directory
$GDUNIT_RUNNER -a "tests"

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "--------------------------------------------------"
    echo "✅ All tests passed!"
else
    echo "--------------------------------------------------"
    echo "❌ Some tests failed with exit code $EXIT_CODE"
fi

exit $EXIT_CODE
