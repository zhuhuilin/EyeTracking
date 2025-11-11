# Tools and Libraries Setup Guide

This document outlines the tools and libraries required to build and run the EyeTracking application on macOS.

## System Requirements

- **Operating System**: macOS 26.1 (BuildVersion: 25B78) or later
- **Architecture**: ARM64 (Apple Silicon) or Intel
- **Xcode**: 26.1 (Build version 17B55) or later

## Core Build Tools

### CMake
- **Version**: 4.1.2
- **Purpose**: Build system for the C++ computer vision core
- **Installation**: `brew install cmake`

### C++ Compiler
- **Compiler**: Apple Clang 17.0.0
- **Standard**: C++17
- **Installation**: Included with Xcode Command Line Tools

## Computer Vision Libraries

### OpenCV
- **Version**: 4.12.0
- **Purpose**: Computer vision and image processing for eye tracking
- **Installation**:
  ```bash
  brew install opencv
  ```
- **Detection**: Available via pkg-config (`pkg-config --modversion opencv4`)

## Flutter Development Environment

### Flutter SDK
- **Version**: 3.35.7 (stable channel)
- **Dart Version**: 3.9.2
- **DevTools Version**: 2.48.0
- **Installation**: Follow [official Flutter installation guide](https://flutter.dev/docs/get-started/install/macos)
- **Channel**: stable

### CocoaPods
- **Version**: 1.16.2
- **Purpose**: Dependency manager for iOS/macOS platform code
- **Installation**: `brew install cocoapods`

## Flutter Dependencies

### Production Dependencies
- **camera**: ^0.10.5 - Camera access for video capture
- **camera_macos**: ^0.0.9 - macOS-specific camera implementation
- **shared_preferences**: ^2.2.2 - Local data persistence
- **sqflite**: ^2.3.0 - SQLite database
- **http**: ^1.1.0 - HTTP client
- **provider**: ^6.1.1 - State management
- **flutter_secure_storage**: ^9.2.4 - Secure data storage
- **path**: ^1.8.3 - File path manipulation
- **collection**: ^1.18.0 - Collection utilities

### Development Dependencies
- **flutter_test**: SDK test framework
- **flutter_lints**: ^3.0.0 - Code linting rules

## Build Process

### 1. Install System Dependencies
```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required tools
brew install cmake opencv cocoapods
```

### 2. Install Flutter
```bash
# Download Flutter SDK
git clone https://github.com/flutter/flutter.git -b stable

# Add Flutter to PATH
export PATH="$PATH:`pwd`/flutter/bin"

# Verify installation
flutter doctor
```

### 3. Setup Flutter Project
```bash
cd flutter_app
flutter pub get
```

### 4. Build C++ Core
```bash
cd core
./build.sh
```

### 5. Build Flutter App
```bash
cd flutter_app
flutter build macos
```

## Platform-Specific Notes

### macOS Build Requirements
- Xcode Command Line Tools must be installed
- CocoaPods is required for plugins that have native macOS code
- Camera permissions must be granted in System Settings

### OpenCV Integration
- The C++ core uses OpenCV 4.x for computer vision algorithms
- OpenCV must be installed and detectable via pkg-config
- The build script automatically detects and links OpenCV libraries

### Flutter Platform Channels
- The app uses platform channels to communicate between Flutter (Dart) and native C++ code
- Camera access requires macOS camera permissions
- Secure storage uses Keychain on macOS

## Troubleshooting

### Common Issues

1. **CocoaPods Installation Fails**
   - Use Homebrew instead of gem: `brew install cocoapods`
   - System Ruby may be outdated for latest CocoaPods

2. **OpenCV Not Found**
   - Ensure OpenCV is installed: `brew install opencv`
   - Verify pkg-config can find it: `pkg-config --modversion opencv4`

3. **Flutter Build Fails**
   - Run `flutter doctor` to check environment
   - Ensure Xcode is properly installed and licensed
   - Check that CocoaPods is installed and working

4. **Camera Permissions**
   - Grant camera access in System Settings > Privacy & Security > Camera
   - Restart the app after granting permissions

## Version Compatibility

- **macOS**: 12.0 or later (tested on 26.1)
- **Xcode**: 14.0 or later (tested on 26.1)
- **Flutter**: 3.0.0 or later (tested on 3.35.7)
- **Dart**: 3.0.0 or later (tested on 3.9.2)

## Additional Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [OpenCV Documentation](https://docs.opencv.org/)
- [CMake Documentation](https://cmake.org/documentation/)
- [CocoaPods Guides](https://guides.cocoapods.org/)
