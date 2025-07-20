#!/bin/bash
# Helper script to run nsys with sudo for CPU sampling support

# Find nsys path
NSYS_PATH=$(which nsys)

if [ -z "$NSYS_PATH" ]; then
    echo "Error: nsys not found in PATH"
    exit 1
fi

echo "Using nsys from: $NSYS_PATH"
echo "Running with sudo for CPU sampling support..."
echo ""

# Pass all arguments to nsys
sudo "$NSYS_PATH" "$@"