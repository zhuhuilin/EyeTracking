#!/bin/bash

# Build script for Android (multiple ABIs)

set -e

echo "============================================"
echo "Building EyeTracking Core for Android"
echo "============================================"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$SCRIPT_DIR/.."
BUILD_DIR="$CORE_DIR/build/android"
INSTALL_DIR="$CORE_DIR/install/android"

# Check for Android NDK
if [ -z "$ANDROID_NDK" ]; then
    echo "ERROR: ANDROID_NDK environment variable not set"
    echo "Please set it to your Android NDK path:"
    echo "  export ANDROID_NDK=/path/to/android-ndk"
    exit 1
fi

if [ ! -d "$ANDROID_NDK" ]; then
    echo "ERROR: Android NDK not found at: $ANDROID_NDK"
    exit 1
fi

# Check for CMake
if ! command -v cmake &> /dev/null; then
    echo "ERROR: CMake not found. Please install CMake"
    exit 1
fi

echo ""
echo "Configuration:"
echo "- Android NDK: $ANDROID_NDK"
echo "- Build Directory: $BUILD_DIR"
echo "- Install Directory: $INSTALL_DIR"
echo ""

# Android ABIs to build
ABIS=("arm64-v8a" "armeabi-v7a" "x86" "x86_64")

for ABI in "${ABIS[@]}"; do
    echo "============================================"
    echo "Building for Android ABI: $ABI"
    echo "============================================"

    ABI_BUILD_DIR="$BUILD_DIR/$ABI"
    ABI_INSTALL_DIR="$INSTALL_DIR/$ABI"

    mkdir -p "$ABI_BUILD_DIR"
    cd "$ABI_BUILD_DIR"

    cmake ../../.. \
        -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK/build/cmake/android.toolchain.cmake" \
        -DANDROID_ABI=$ABI \
        -DANDROID_PLATFORM=android-21 \
        -DANDROID_STL=c++_shared \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$ABI_INSTALL_DIR"

    cmake --build . --config Release -j$(nproc 2>/dev/null || echo 4)
    cmake --install . --config Release

    echo ""
done

echo "============================================"
echo "Build completed successfully for all ABIs!"
echo "============================================"
echo "Output: $INSTALL_DIR"
for ABI in "${ABIS[@]}"; do
    echo "  - $ABI: $INSTALL_DIR/$ABI"
done
echo ""
