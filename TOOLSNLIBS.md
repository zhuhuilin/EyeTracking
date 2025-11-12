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

### YuNet Face Detection Model
- **Model**: `face_detection_yunet_2023mar.onnx` (bundled in `core/models/`)
- **Purpose**: Primary face detector (OpenCV FaceDetectorYN) with Haar cascade fallback
- **Runtime Path Resolution**:
  - Automatically copied into the macOS app bundle at `Runner.app/Contents/Resources/`
  - Override by setting `EYETRACKING_FACE_MODEL=/absolute/path/to/face_detection_yunet_2023mar.onnx`
- **Installation**: Model is version-controlled; no manual download required

### YOLO Face Detection Model (CoreML, macOS Preview)
- **Model**: `yolo11m.mlpackage` (exported from Ultralytics `yolo11m.pt` with `nms=True`)
- **Purpose**: High-accuracy backend accelerated by CoreML for the macOS preview widget (selected via the camera dialog or `EYETRACKING_FACE_BACKEND=yolo`)
- **Location**: Place the compiled package at `flutter_app/macos/Runner/Resources/yolo11m.mlpackage`
- **Conversion**:
  ```bash
  python3 -m pip install --user ultralytics coremltools
  ~/Library/Python/3.9/bin/yolo export model=yolo11m.pt format=coreml imgsz=640 nms=True
  mv yolo11m.mlpackage flutter_app/macos/Runner/Resources/
  ```
  The build phase named **Copy Face Detection Models** will copy `.mlpackage` folders into `Runner.app/Contents/Resources/` automatically.
- **Notes**:
  - The CoreML path is only required on macOS; iOS/iPadOS support will reuse the same asset.
  - The plugin falls back to YuNet/Haar automatically if the CoreML model is missing.

### YOLO Face Detection Model (Legacy ONNX Fallback)
- **Model**: `yolov5n-face.onnx` or any YOLOv5/YOLOv8 face detector with standard output tensors
- **Purpose**: Retained for the C++ core and non-macOS builds
- **Default Path**: `core/models/yolov5n-face.onnx`
- **Environment Override**: `EYETRACKING_YOLO_FACE_MODEL=/absolute/path/to/model.onnx`
- **Download**:
  ```bash
  curl -L -H "Accept: application/octet-stream" \
    -o core/models/yolov5n-face.onnx \
    "https://github.com/deepcam-cn/yolov5-face/releases/download/0.0/yolov5n-face.onnx"
  ```
  > If GitHub returns HTML, clone the upstream repo using Git LFS (`git lfs install && git clone ...`) and copy the ONNX file manually.

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
