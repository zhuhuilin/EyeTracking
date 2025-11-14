#!/bin/bash

# Build script for iOS (both simulator and device)

set -e

echo "============================================"
echo "Building EyeTracking Core for iOS"
echo "============================================"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$SCRIPT_DIR/.."
BUILD_DIR="$CORE_DIR/build/ios"
INSTALL_DIR="$CORE_DIR/install/ios"

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "ERROR: iOS builds require macOS"
    exit 1
fi

# Check for CMake
if ! command -v cmake &> /dev/null; then
    echo "ERROR: CMake not found. Please install CMake"
    exit 1
fi

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "ERROR: Xcode not found. Please install Xcode"
    exit 1
fi

echo ""
echo "Configuration:"
echo "- Build Directory: $BUILD_DIR"
echo "- Install Directory: $INSTALL_DIR"
echo ""

# Build for iOS Device (ARM64)
echo "Building for iOS Device (ARM64)..."
mkdir -p "$BUILD_DIR/device"
cd "$BUILD_DIR/device"
cmake ../.. \
    -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=iphoneos \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR/device" \
    -DCMAKE_BUILD_TYPE=Release

cmake --build . --config Release
cmake --install . --config Release

# Build for iOS Simulator (x86_64 and ARM64)
echo ""
echo "Building for iOS Simulator..."
mkdir -p "$BUILD_DIR/simulator"
cd "$BUILD_DIR/simulator"
cmake ../.. \
    -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=iphonesimulator \
    -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64" \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR/simulator" \
    -DCMAKE_BUILD_TYPE=Release

cmake --build . --config Release
cmake --install . --config Release

echo ""
echo "============================================"
echo "Build completed successfully!"
echo "============================================"
echo "Device output: $INSTALL_DIR/device"
echo "Simulator output: $INSTALL_DIR/simulator"
echo ""
