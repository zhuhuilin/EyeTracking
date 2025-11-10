#!/bin/bash

# EyeBall Tracking Core Build Script
# This script builds the C++ computer vision core for all target platforms

set -e

# Configuration
BUILD_DIR="build"
INSTALL_DIR="install"
PLATFORMS=("linux" "macos" "windows" "android" "ios")
CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=Release"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check dependencies
check_dependencies() {
    print_info "Checking build dependencies..."
    
    # Check CMake
    if ! command -v cmake &> /dev/null; then
        print_error "CMake is required but not installed. Please install CMake."
        exit 1
    fi
    
    # Check OpenCV
    if ! pkg-config --exists opencv4; then
        print_warning "OpenCV 4 not found via pkg-config. Trying alternative detection..."
        if [ ! -d "/usr/local/include/opencv4" ] && [ ! -d "/usr/include/opencv4" ]; then
            print_error "OpenCV 4 is required but not found. Please install OpenCV 4."
            exit 1
        fi
    fi
    
    print_info "All dependencies found."
}

# Create build directories
setup_directories() {
    print_info "Setting up build directories..."
    mkdir -p $BUILD_DIR
    mkdir -p $INSTALL_DIR
}

# Build for Linux
build_linux() {
    print_info "Building for Linux..."
    local build_dir="$BUILD_DIR/linux"
    mkdir -p $build_dir
    cd $build_dir
    
    cmake ../.. $CMAKE_FLAGS
    make -j$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
    
    # Copy library to install directory
    mkdir -p ../../$INSTALL_DIR/linux
    cp libeyeball_tracking_core.so ../../$INSTALL_DIR/linux/ 2>/dev/null || cp libeyeball_tracking_core.dylib ../../$INSTALL_DIR/linux/ 2>/dev/null || print_warning "No library file found to copy"
    
    cd ../..
    print_info "Linux build completed."
}

# Build for macOS
build_macos() {
    print_info "Building for macOS..."
    local build_dir="$BUILD_DIR/macos"
    mkdir -p $build_dir
    cd $build_dir
    
    cmake ../.. $CMAKE_FLAGS
    make -j$(sysctl -n hw.ncpu)
    
    # Copy library to install directory
    mkdir -p ../../$INSTALL_DIR/macos
    cp libeyeball_tracking_core.dylib ../../$INSTALL_DIR/macos/
    
    cd ../..
    print_info "macOS build completed."
}

# Build for Windows (cross-compilation)
build_windows() {
    print_info "Building for Windows (cross-compilation)..."
    local build_dir="$BUILD_DIR/windows"
    mkdir -p $build_dir
    cd $build_dir
    
    # This requires mingw-w64 to be installed
    if command -v x86_64-w64-mingw32-cmake &> /dev/null; then
        x86_64-w64-mingw32-cmake ../.. $CMAKE_FLAGS
        make -j$(nproc)
        
        mkdir -p ../../$INSTALL_DIR/windows
        cp libeyeball_tracking_core.dll ../../$INSTALL_DIR/windows/
    else
        print_warning "mingw-w64 not found. Skipping Windows build."
    fi
    
    cd ../..
}

# Build for Android (requires Android NDK)
build_android() {
    print_info "Building for Android..."
    local build_dir="$BUILD_DIR/android"
    mkdir -p $build_dir
    cd $build_dir
    
    # Check for Android NDK
    if [ -z "$ANDROID_NDK" ]; then
        print_warning "ANDROID_NDK environment variable not set. Skipping Android build."
        cd ../..
        return
    fi
    
    # Build for multiple ABIs
    for abi in armeabi-v7a arm64-v8a x86 x86_64; do
        print_info "Building for Android ABI: $abi"
        mkdir -p $abi
        cd $abi
        
        cmake ../../.. \
            -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
            -DANDROID_ABI=$abi \
            -DANDROID_PLATFORM=android-21 \
            $CMAKE_FLAGS
            
        make -j$(nproc)
        
        mkdir -p ../../../$INSTALL_DIR/android/$abi
        cp libeyeball_tracking_core.so ../../../$INSTALL_DIR/android/$abi/
        
        cd ..
    done
    
    cd ../..
    print_info "Android build completed."
}

# Build for iOS (requires Xcode)
build_ios() {
    print_info "Building for iOS..."
    local build_dir="$BUILD_DIR/ios"
    mkdir -p $build_dir
    cd $build_dir
    
    # Check if we're on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_warning "iOS builds require macOS. Skipping iOS build."
        cd ../..
        return
    fi
    
    # Build for iOS simulator and device
    for sdk in iphonesimulator iphoneos; do
        print_info "Building for iOS SDK: $sdk"
        mkdir -p $sdk
        cd $sdk
        
        cmake ../../.. \
            -DCMAKE_TOOLCHAIN_FILE=../../ios.toolchain.cmake \
            -DPLATFORM=$sdk \
            $CMAKE_FLAGS
            
        make -j$(sysctl -n hw.ncpu)
        
        mkdir -p ../../../$INSTALL_DIR/ios/$sdk
        cp libeyeball_tracking_core.a ../../../$INSTALL_DIR/ios/$sdk/
        
        cd ..
    done
    
    cd ../..
    print_info "iOS build completed."
}

# Generate Flutter platform channel bindings
generate_bindings() {
    print_info "Generating Flutter platform channel bindings..."
    
    # Create directory for generated bindings
    mkdir -p ../flutter_app/ios/Classes
    mkdir -p ../flutter_app/android/src/main/cpp
    
    # Generate header file for Flutter integration
    cat > include/flutter_bindings.h << 'EOF'
#ifndef FLUTTER_BINDINGS_H
#define FLUTTER_BINDINGS_H

#include "tracking_engine.h"
#include <flutter/standard_method_codec.h>

class FlutterBindings {
public:
    static void RegisterWithRegistrar(flutter::PluginRegistrar *registrar);
    
private:
    static void HandleMethodCall(
        const flutter::MethodCall<flutter::EncodableValue> &method_call,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
    
    static TrackingEngine* GetTrackingEngine();
    
    // Method handlers
    static void InitializeTrackingEngine(
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
    static void StartTracking(
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
    static void StopTracking(
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
    static void ProcessFrame(
        const flutter::EncodableValue& arguments,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
    static void SetCameraParameters(
        const flutter::EncodableValue& arguments,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
    static void StartCalibration(
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
    static void AddCalibrationPoint(
        const flutter::EncodableValue& arguments,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
    static void FinishCalibration(
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

#endif // FLUTTER_BINDINGS_H
EOF

    print_info "Bindings generated."
}

# Package the build results
package_build() {
    print_info "Packaging build results..."
    
    # Create a version file
    cat > $INSTALL_DIR/VERSION << EOF
EyeBall Tracking Core Library
Version: 1.0.0
Build Date: $(date)
Platforms: ${PLATFORMS[@]}
EOF

    # Create README for the installation
    cat > $INSTALL_DIR/README.md << 'EOF'
# EyeBall Tracking Core Libraries

This directory contains the compiled C++ core libraries for the EyeBall Tracking application.

## Platform Support

- **Linux**: `libeyeball_tracking_core.so`
- **macOS**: `libeyeball_tracking_core.dylib`
- **Windows**: `libeyeball_tracking_core.dll`
- **Android**: Multiple ABI versions in `android/` directory
- **iOS**: Simulator and device versions in `ios/` directory

## Integration

These libraries are automatically integrated with the Flutter application through platform channels.

## Dependencies

- OpenCV 4.8.0 or later
- C++17 compatible compiler

## Building from Source

See the main project README for build instructions.
EOF

    print_info "Packaging completed."
}

# Main build function
main() {
    print_info "Starting EyeBall Tracking Core build process..."
    
    check_dependencies
    setup_directories
    
    # Build for each platform
    for platform in "${PLATFORMS[@]}"; do
        case $platform in
            "linux")
                build_linux
                ;;
            "macos")
                build_macos
                ;;
            "windows")
                build_windows
                ;;
            "android")
                build_android
                ;;
            "ios")
                build_ios
                ;;
        esac
    done
    
    generate_bindings
    package_build
    
    print_info "Build process completed successfully!"
    print_info "Libraries are available in: $INSTALL_DIR/"
}

# Run main function
main "$@"
