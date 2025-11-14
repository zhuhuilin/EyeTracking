#!/bin/bash

# Build script for macOS

set -e

echo "============================================"
echo "Building EyeTracking Core for macOS"
echo "============================================"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$SCRIPT_DIR/.."
BUILD_DIR="$CORE_DIR/build/macos"
INSTALL_DIR="$CORE_DIR/install/macos"

# Check for CMake
if ! command -v cmake &> /dev/null; then
    echo "ERROR: CMake not found. Please install CMake"
    echo "  brew install cmake"
    exit 1
fi

# Check for OpenCV (via Homebrew or vcpkg)
if ! pkg-config --exists opencv4 2>/dev/null; then
    echo "WARNING: OpenCV 4 not found via pkg-config"
    echo "  Install via: brew install opencv"
fi

echo ""
echo "Configuration:"
echo "- Build Directory: $BUILD_DIR"
echo "- Install Directory: $INSTALL_DIR"
echo ""

# Create build directory
mkdir -p "$BUILD_DIR"

# Configure with CMake
echo "Configuring CMake..."
cd "$BUILD_DIR"
cmake ../.. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR"

# Build
echo ""
echo "Building..."
cmake --build . --config Release -j$(sysctl -n hw.ncpu)

# Install
echo ""
echo "Installing to $INSTALL_DIR..."
cmake --install . --config Release

echo ""
echo "============================================"
echo "Build completed successfully!"
echo "============================================"
echo "Output: $INSTALL_DIR"
echo ""
