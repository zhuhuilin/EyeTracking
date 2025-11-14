# Platform-Specific Dependencies Guide

This document explains how dependencies are managed separately for each platform to avoid conflicts.

## Overview

Each platform maintains its own isolated dependency installation:

```
vcpkg/installed/          # Windows dependencies (managed by vcpkg)
├── arm64-windows/        # Windows ARM64 specific
│   ├── bin/
│   ├── lib/
│   └── include/
└── x64-windows/          # Windows x64 specific
    ├── bin/
    ├── lib/
    └── include/

/usr/local/              # macOS dependencies (Homebrew)
├── Cellar/opencv/       # macOS specific
└── lib/

core/dependencies/       # iOS & Android dependencies (manual)
├── ios/
│   └── OpenCV.framework/
└── android/
    └── OpenCV-android-sdk/
```

## Why Separate Dependencies?

1. **No Conflicts**: Each platform has different binary formats (x64 vs ARM64, Windows vs macOS vs Linux)
2. **Clean Builds**: Building for one platform won't affect another
3. **Easy Management**: Install/uninstall dependencies per platform independently
4. **Version Control**: Dependencies are git-ignored, keeping repository small

## Installation Instructions by Platform

### Windows ARM64

**Location**: `C:\vcpkg\installed\arm64-windows\`

**Install Dependencies**:
```cmd
cd core\scripts
install-deps-windows-arm64.bat
```

**What it installs**:
- OpenCV 4.11.0 with DNN module
- All OpenCV dependencies (protobuf, libjpeg, libpng, etc.)
- Compiled specifically for ARM64 architecture

**Time**: ~15-20 minutes (builds from source)

---

### Windows x64

**Location**: `C:\vcpkg\installed\x64-windows\`

**Install Dependencies**:
```cmd
cd core\scripts
install-deps-windows-x64.bat
```

**What it installs**:
- OpenCV 4.11.0 with DNN module
- All OpenCV dependencies
- Compiled specifically for x64 architecture

**Time**: ~15-20 minutes (builds from source)

---

### macOS (Universal Binary: ARM64 + x86_64)

**Location**: `/usr/local/Cellar/opencv/` or `$(brew --prefix opencv)`

**Install Dependencies**:
```bash
cd core/scripts
./install-deps-macos.sh
```

**What it installs**:
- OpenCV 4.x (latest stable via Homebrew)
- Universal binary supporting both Intel and Apple Silicon Macs

**Time**: ~5 minutes (pre-built bottles)

**Alternative - vcpkg**:
```bash
vcpkg install opencv4[dnn]:arm64-osx    # For Apple Silicon
vcpkg install opencv4[dnn]:x64-osx      # For Intel Macs
```

---

### iOS

**Location**: `core/dependencies/ios/`

**Install Dependencies**:
```bash
cd core/scripts
./install-deps-ios.sh
```

This script provides instructions for obtaining OpenCV for iOS:

**Option 1**: Download pre-built framework
- Visit: https://opencv.org/releases/
- Download iOS framework
- Place in: `core/dependencies/ios/OpenCV.framework`

**Option 2**: Build from source
- Use OpenCV source with iOS toolchain
- Supports both device (ARM64) and simulator (x86_64/ARM64)

**Option 3**: CocoaPods
```ruby
pod 'OpenCV'
```

---

### Android

**Location**: `core/dependencies/android/`

**Install Dependencies**:
```bash
cd core/scripts
./install-deps-android.sh
```

This script provides instructions for obtaining OpenCV Android SDK:

**Recommended**: Download OpenCV Android SDK
1. Visit: https://opencv.org/releases/
2. Download "OpenCV - X.X.X - Android"
3. Extract to: `core/dependencies/android/OpenCV-android-sdk`

**Supported ABIs**:
- arm64-v8a (64-bit ARM)
- armeabi-v7a (32-bit ARM)
- x86 (32-bit x86 emulator)
- x86_64 (64-bit x86 emulator)

---

## Verifying Installations

### Windows (vcpkg)
```cmd
REM List all installed packages for a platform
vcpkg list | findstr "arm64-windows"
vcpkg list | findstr "x64-windows"

REM Check specific package
vcpkg list opencv4:arm64-windows
```

### macOS (Homebrew)
```bash
# Check if OpenCV is installed
brew list | grep opencv

# Show OpenCV info
brew info opencv

# Show installation path
brew --prefix opencv
```

### iOS / Android
```bash
# Check if dependencies directory exists
ls -la core/dependencies/ios/
ls -la core/dependencies/android/
```

---

## Troubleshooting

### Windows: "Package already installed for different triplet"

This is normal! vcpkg can have the same package installed for multiple triplets:
- `opencv4:arm64-windows` - For ARM64 builds
- `opencv4:x64-windows` - For x64 builds

They don't conflict because they're in separate directories.

### macOS: "OpenCV not found"

```bash
# Verify Homebrew installation
brew doctor

# Reinstall OpenCV
brew reinstall opencv

# Check pkg-config
pkg-config --modversion opencv4
```

### iOS/Android: "Framework/SDK not found"

Make sure you've downloaded and placed the OpenCV framework/SDK in the correct location as shown in the installation scripts.

---

## Cleaning Up Dependencies

### Windows
```cmd
REM Remove ARM64 dependencies
vcpkg remove opencv4:arm64-windows --recurse

REM Remove x64 dependencies
vcpkg remove opencv4:x64-windows --recurse
```

### macOS
```bash
brew uninstall opencv
```

### iOS/Android
```bash
# Simply delete the dependencies directory
rm -rf core/dependencies/ios
rm -rf core/dependencies/android
```

---

## Dependency Versions

| Platform | OpenCV Version | Install Method | Location |
|----------|---------------|----------------|----------|
| Windows ARM64 | 4.11.0 | vcpkg | `C:\vcpkg\installed\arm64-windows\` |
| Windows x64 | 4.11.0 | vcpkg | `C:\vcpkg\installed\x64-windows\` |
| macOS | 4.x (latest) | Homebrew | `/usr/local/` or `/opt/homebrew/` |
| iOS | 4.x+ | Manual/CocoaPods | `core/dependencies/ios/` |
| Android | 4.x+ | Manual download | `core/dependencies/android/` |

---

## Advanced: Using a Shared vcpkg Root

If you want all developers to use the same vcpkg installation, set an environment variable:

**Windows**:
```cmd
setx VCPKG_ROOT "C:\vcpkg"
```

**macOS/Linux**:
```bash
export VCPKG_ROOT="/path/to/vcpkg"
echo 'export VCPKG_ROOT="/path/to/vcpkg"' >> ~/.bashrc
```

Then all build scripts will automatically use that vcpkg installation.

---

## Summary

- **Windows**: vcpkg manages separate arm64-windows and x64-windows packages
- **macOS**: Homebrew installs universal binaries at system level
- **iOS/Android**: Manual download to project-local `dependencies/` directory
- **No conflicts**: Each platform is completely isolated
- **Shared codebase**: All platforms use the same C++ source code
- **Git-friendly**: All dependencies are gitignored
