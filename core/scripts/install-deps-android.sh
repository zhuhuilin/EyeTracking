#!/bin/bash

# Install dependencies for Android

set -e

echo "============================================"
echo "Installing Dependencies for Android"
echo "============================================"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPS_DIR="$SCRIPT_DIR/../dependencies/android"

echo ""
echo "Android requires OpenCV SDK for Android."
echo ""
echo "Option 1: Download OpenCV Android SDK (Recommended)"
echo "  1. Visit: https://opencv.org/releases/"
echo "  2. Download 'OpenCV - X.X.X - Android'"
echo "  3. Extract to: $DEPS_DIR/OpenCV-android-sdk"
echo ""
echo "Option 2: Build OpenCV for Android yourself"
echo "  Use OpenCV source with Android NDK"
echo ""

# Create dependencies directory structure
mkdir -p "$DEPS_DIR"

echo "Dependencies directory created: $DEPS_DIR"
echo ""
echo "After downloading OpenCV Android SDK, your structure should be:"
echo "  $DEPS_DIR/"
echo "    └── OpenCV-android-sdk/"
echo "        ├── sdk/"
echo "        │   ├── native/"
echo "        │   │   ├── libs/"
echo "        │   │   │   ├── arm64-v8a/"
echo "        │   │   │   ├── armeabi-v7a/"
echo "        │   │   │   ├── x86/"
echo "        │   │   │   └── x86_64/"
echo "        │   │   └── jni/"
echo "        │   │       └── include/"
echo "        │   └── java/"
echo "        └── README.md"
echo ""
echo "Then update the Android build script with:"
echo "  export OPENCV_ANDROID_SDK=$DEPS_DIR/OpenCV-android-sdk"
echo ""
