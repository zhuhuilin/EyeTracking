# EyeTracking Core - Multi-Platform Build Guide

This document explains how to build the eye tracking core library for different platforms.

## Architecture Overview

The project maintains a **single shared codebase** with **platform-specific build directories**:

```
core/
├── src/                    # Shared C++ source code
├── include/                # Shared C++ headers
├── models/                 # Shared ML models
├── CMakeLists.txt         # Main CMake configuration
├── cmake/                 # Platform-specific toolchain files
│   ├── toolchain-windows-x64.cmake
│   ├── toolchain-windows-arm64.cmake
│   ├── toolchain-macos.cmake
│   ├── toolchain-ios.cmake
│   └── toolchain-android.cmake
├── scripts/               # Platform-specific build scripts
│   ├── build-windows-x64.bat
│   ├── build-windows-arm64.bat
│   ├── build-macos.sh
│   ├── build-ios.sh
│   └── build-android.sh
├── build/                 # Build artifacts (per platform, gitignored)
│   ├── windows-x64/
│   ├── windows-arm64/
│   ├── macos/
│   ├── ios/
│   └── android/
└── install/               # Installation output (per platform)
    ├── windows-x64/
    ├── windows-arm64/
    ├── macos/
    ├── ios/
    └── android/
```

## Prerequisites by Platform

### Windows x64
- Visual Studio 2022 with x64 C++ tools
- CMake 3.16+
- vcpkg (for OpenCV)
- OpenCV 4.8.0+ with DNN module

### Windows ARM64
- Visual Studio 2022 with ARM64 C++ tools
- CMake 3.16+
- vcpkg (for OpenCV)
- OpenCV 4.8.0+ with DNN module

### macOS
- Xcode 14+
- CMake 3.16+
- Homebrew
- OpenCV 4.8.0+ (via Homebrew or vcpkg)

### iOS
- macOS with Xcode 14+
- CMake 3.16+
- OpenCV built for iOS

### Android
- Android Studio
- Android NDK r21+
- CMake 3.16+
- OpenCV built for Android

## Building for Each Platform

**Note**: Build scripts now use dedicated CMake toolchain files located in `core/cmake/` for better organization and consistency.

### Windows x64

```cmd
cd core\scripts
build-windows-x64.bat
```

Uses toolchain: `core/cmake/toolchain-windows-x64.cmake`
Output: `core/install/windows-x64/eyeball_tracking_core.dll`

### Windows ARM64

```cmd
cd core\scripts
build-windows-arm64.bat
```

Uses toolchain: `core/cmake/toolchain-windows-arm64.cmake`
Output: `core/install/windows-arm64/eyeball_tracking_core.dll`

### macOS

```bash
cd core/scripts
./build-macos.sh
```

Output: `core/install/macos/libeyeball_tracking_core.dylib`

### iOS

```bash
cd core/scripts
./build-ios.sh
```

Output: `core/install/ios/{simulator,device}/libeyeball_tracking_core.a`

### Android

```bash
cd core/scripts
./build-android.sh
```

Output: `core/install/android/{arm64-v8a,armeabi-v7a,x86,x86_64}/libeyeball_tracking_core.so`

## Clean Builds

To clean a specific platform:

```bash
# Windows
rmdir /s /q core\build\windows-x64
rmdir /s /q core\install\windows-x64

# Unix-like (macOS, iOS, Android)
rm -rf core/build/macos
rm -rf core/install/macos
```

## vcpkg Integration

Each Windows platform uses its own vcpkg triplet:

- **Windows x64**: `x64-windows`
- **Windows ARM64**: `arm64-windows`

Install OpenCV for your target platform:

```bash
# Windows x64
vcpkg install opencv4[dnn]:x64-windows

# Windows ARM64
vcpkg install opencv4[dnn]:arm64-windows
```

## Troubleshooting

### Build conflicts between platforms

Each platform has its own isolated build directory. If you experience issues:

1. Delete the specific platform's build directory
2. Rebuild from scratch for that platform
3. Other platforms remain unaffected

### Missing OpenCV

Ensure OpenCV is installed for the specific target platform/architecture you're building for.

### Cross-compilation

- **Windows**: Cannot cross-compile between x64 and ARM64 on the same machine easily. Build natively or use appropriate toolchains.
- **iOS**: Requires macOS
- **Android**: Can be built on any platform with Android NDK
