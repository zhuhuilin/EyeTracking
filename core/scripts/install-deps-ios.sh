#!/bin/bash

# Install dependencies for iOS

set -e

echo "============================================"
echo "Installing Dependencies for iOS"
echo "============================================"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPS_DIR="$SCRIPT_DIR/../dependencies/ios"

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "ERROR: iOS dependencies can only be installed on macOS"
    exit 1
fi

echo ""
echo "iOS requires OpenCV built specifically for iOS."
echo ""
echo "Option 1: Build OpenCV yourself for iOS"
echo "  Download OpenCV source and build using ios.toolchain.cmake"
echo ""
echo "Option 2: Use pre-built OpenCV framework"
echo "  Download from: https://opencv.org/releases/"
echo "  Or use CocoaPods: pod 'OpenCV'"
echo ""
echo "Option 3: Use vcpkg (experimental iOS support)"
echo "  vcpkg install opencv4[dnn]:arm64-ios"
echo ""

# Create dependencies directory
mkdir -p "$DEPS_DIR"

echo "Dependencies directory created: $DEPS_DIR"
echo ""
echo "Please place OpenCV.framework in:"
echo "  $DEPS_DIR/OpenCV.framework"
echo ""
echo "Or update the iOS build script to point to your OpenCV installation."
echo ""
