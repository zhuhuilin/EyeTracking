# Flutter Platform Plugin Structure Guide

This document explains how platform-specific native code is organized to avoid conflicts between Windows, macOS, iOS, and Android implementations.

## Overview

The EyeTracking Flutter app uses **Platform Channels** to communicate with native C++ code for computer vision processing. Each platform has its own isolated implementation.

## Current Structure

```
flutter_app/
├── lib/                          # Shared Dart code (all platforms)
│   ├── main.dart
│   ├── models/
│   ├── pages/
│   ├── services/
│   │   └── camera_service.dart   # Platform channel interface
│   └── widgets/
├── macos/                        # macOS native implementation ✅
│   └── Runner/
│       ├── EyeTrackingPlugin.swift
│       ├── CoreMLYoloDetector.swift
│       └── tracking_engine_bridge.h
├── windows/                      # Windows native implementation ⚠️ TODO
├── ios/                          # iOS native implementation ⚠️ TODO
└── android/                      # Android native implementation ⚠️ TODO
```

**Status**:
- ✅ **macOS**: Fully implemented
- ⚠️ **Windows, iOS, Android**: Need to be added

---

## Platform Channel Architecture

### Shared Interface (Dart)

All platforms use the same Dart interface in `lib/services/camera_service.dart`:

```dart
class CameraService {
  static const MethodChannel _cameraChannel = MethodChannel('eyeball_tracking/camera');
  static const EventChannel _trackingChannel = EventChannel('eyeball_tracking/tracking');

  // Shared methods - implemented differently per platform
  Future<void> initializeCamera() async { ... }
  Future<void> startTracking() async { ... }
  Stream<TrackingResult> getTrackingStream() { ... }
}
```

**Key Points**:
- Channel names are the same across all platforms
- Method signatures are identical
- Only the native implementation differs

---

## Platform-Specific Implementations

### macOS Implementation (Reference)

**Location**: `flutter_app/macos/Runner/`

**Files**:
- `EyeTrackingPlugin.swift` - Main plugin, handles method/event channels
- `CoreMLYoloDetector.swift` - CoreML-specific face detection
- `tracking_engine_bridge.h` - C bridge to C++ core library

**Structure**:
```swift
// EyeTrackingPlugin.swift
class EyeTrackingPlugin: NSObject, FlutterPlugin {
    static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(...)
        let eventChannel = FlutterEventChannel(...)
        // Register handlers
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initializeCamera": // Platform-specific implementation
        case "startTracking":    // Platform-specific implementation
        // ...
        }
    }
}
```

**Integration with C++**:
```swift
import tracking_engine_bridge // C bridge header

let trackingEngine = TrackingEngineCreate()
TrackingEngineInitialize(trackingEngine)
```

---

### Windows Implementation (TODO)

**Target Location**: `flutter_app/windows/`

**Recommended Structure**:
```
windows/
├── CMakeLists.txt               # Build configuration
├── runner/
│   ├── main.cpp                # Flutter entry point
│   ├── win32_window.cpp       # Window management
│   └── flutter_window.cpp     # Flutter embedding
└── plugins/
    └── eyetracking_plugin/    # NEW - Our plugin
        ├── eyetracking_plugin.h
        ├── eyetracking_plugin.cpp
        └── CMakeLists.txt
```

**Implementation Example** (`eyetracking_plugin.cpp`):
```cpp
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include "tracking_engine_bridge.h"  // C++ core

class EyeTrackingPlugin : public flutter::Plugin {
public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};
```

**Key Differences from macOS**:
- Use `flutter/plugin_registrar_windows.h` instead of Flutter for macOS headers
- Windows-specific window management
- Link against `eyeball_tracking_core.dll` (Windows ARM64 or x64)

---

### iOS Implementation (TODO)

**Target Location**: `flutter_app/ios/`

**Recommended Structure**:
```
ios/
├── Runner/
│   ├── AppDelegate.swift      # App lifecycle
│   ├── Runner-Bridging-Header.h
│   └── Plugins/              # NEW
│       └── EyeTrackingPlugin.swift
└── Runner.xcworkspace
```

**Implementation** (`EyeTrackingPlugin.swift`):
```swift
import Flutter
import UIKit

public class EyeTrackingPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
        name: "eyeball_tracking/camera",
        binaryMessenger: registrar.messenger())
    let instance = EyeTrackingPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initializeCamera": // iOS camera implementation
    case "startTracking":    // iOS tracking implementation
    default: result(FlutterMethodNotImplemented)
    }
  }
}
```

**Key Differences from macOS**:
- May use different camera APIs (AVFoundation vs macOS-specific APIs)
- Link against `libeyeball_tracking_core.a` (static library for iOS)
- CoreML models can be shared with macOS

---

### Android Implementation (TODO)

**Target Location**: `flutter_app/android/`

**Recommended Structure**:
```
android/
├── app/
│   └── src/
│       └── main/
│           ├── java/com/example/eyeball_tracking/
│           │   └── MainActivity.java
│           └── cpp/           # NEW - JNI bindings
│               ├── CMakeLists.txt
│               ├── eyetracking_plugin.cpp
│               └── tracking_engine_jni.cpp
└── build.gradle
```

**Implementation** (`eyetracking_plugin.cpp` - JNI):
```cpp
#include <jni.h>
#include <flutter/method_channel.h>
#include "tracking_engine_bridge.h"

extern "C" JNIEXPORT void JNICALL
Java_com_example_eyeball_1tracking_EyeTrackingPlugin_initializeCamera(
    JNIEnv* env, jobject /* this */) {
    // Android-specific camera initialization
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_eyeball_1tracking_EyeTrackingPlugin_startTracking(
    JNIEnv* env, jobject /* this */) {
    // Android-specific tracking
}
```

**Java Side** (`EyeTrackingPlugin.java`):
```java
package com.example.eyeball_tracking;

import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;

public class EyeTrackingPlugin implements MethodCallHandler {
    static {
        System.loadLibrary("eyeball_tracking_core");  // Load native library
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        switch (call.method) {
            case "initializeCamera":
                initializeCamera();
                result.success(null);
                break;
            // ...
        }
    }

    private native void initializeCamera();  // JNI method
    private native void startTracking();
}
```

---

## Isolation Strategy

### 1. Separate Platform Directories

Each platform has its own directory - changes to one platform don't affect others:
- `macos/` - macOS code
- `windows/` - Windows code
- `ios/` - iOS code
- `android/` - Android code

### 2. Shared Channel Names

All platforms use identical channel names so Dart code works everywhere:
```dart
static const MethodChannel _cameraChannel = MethodChannel('eyeball_tracking/camera');
```

### 3. Platform Detection in Dart

Use `dart:io` Platform class for platform-specific logic in Dart:
```dart
import 'dart:io' show Platform;

if (Platform.isMacOS) {
  // macOS-specific Dart code
} else if (Platform.isWindows) {
  // Windows-specific Dart code
}
```

### 4. Native Library Linking

Each platform links against its own build of the C++ core:
- **Windows x64**: `core/install/windows-x64/eyeball_tracking_core.dll`
- **Windows ARM64**: `core/install/windows-arm64/eyeball_tracking_core.dll`
- **macOS**: `core/install/macos/libeyeball_tracking_core.dylib`
- **iOS**: `core/install/ios/device/libeyeball_tracking_core.a`
- **Android**: `core/install/android/{abi}/libeyeball_tracking_core.so`

---

## Adding a New Platform

### Step 1: Create Platform Directory

If Flutter hasn't created it yet:
```bash
flutter create --platforms=windows,android,ios .
```

### Step 2: Create Plugin Structure

Create plugin files in the platform directory (see examples above).

### Step 3: Implement Platform Channel Handlers

Implement handlers for all methods defined in `camera_service.dart`:
- `initializeCamera`
- `startTracking`
- `stopTracking`
- `processFrame`
- `selectCamera`
- `setFaceDetectionBackend`
- etc.

### Step 4: Link C++ Core Library

Configure build system to link platform-specific core library:
- **Windows**: Update `CMakeLists.txt` to find/link DLL
- **iOS**: Add static library to Xcode project
- **Android**: Update `CMakeLists.txt` to find/link SO

### Step 5: Handle Platform-Specific Features

Some features may differ per platform:
- Camera access APIs
- File system paths
- Threading models
- GPU acceleration

### Step 6: Test Platform Independently

Build and test on target platform without affecting others:
```bash
flutter run -d windows   # Test Windows
flutter run -d macos    # Test macOS
flutter run -d android  # Test Android
```

---

## Common Pitfalls

### ❌ Hardcoded Paths

**Bad**:
```dart
final modelPath = '/Users/username/models/face.onnx';  // macOS only!
```

**Good**:
```dart
final modelPath = await getApplicationDocumentsDirectory();  // Cross-platform
```

### ❌ Platform-Specific Types in Shared Code

**Bad**:
```dart
// In camera_service.dart (shared)
import 'package:camera_macos/camera_macos.dart';  // macOS only!
```

**Good**:
```dart
// In camera_service.dart (shared)
import 'package:camera/camera.dart';  // Cross-platform
```

### ❌ Mixing Platform Implementations

**Bad**:
```
macos/
└── Runner/
    ├── EyeTrackingPlugin.swift
    └── WindowsSpecificCode.cpp  // Wrong platform!
```

**Good**:
Keep each platform's code in its own directory.

---

## Best Practices

1. **Test on actual devices**: Emulators/simulators behave differently
2. **Use platform-agnostic plugins**: Prefer `package:camera` over platform-specific camera packages when possible
3. **Document platform differences**: Note in comments where implementations diverge
4. **Share business logic**: Keep platform-specific code minimal, share Dart logic
5. **Version control**: Commit platform directories separately in git
6. **CI/CD isolation**: Build/test each platform in separate CI jobs

---

## Debugging

### Method Channel Not Found

**Symptoms**: `MissingPluginException`

**Solutions**:
1. Verify plugin is registered in platform's entry point
2. Check channel name matches exactly
3. Rebuild and restart app
4. Check platform-specific logs

### Native Crash

**Symptoms**: App crashes in native code

**Solutions**:
1. Check native debugger (Xcode, Visual Studio, Android Studio)
2. Verify C++ library is properly linked
3. Check for null pointer dereferences
4. Verify frame data format matches expectations

---

## Summary

- **Dart interface**: Shared across all platforms (`camera_service.dart`)
- **Native implementations**: Platform-specific (`macos/`, `windows/`, etc.)
- **Channel names**: Identical across platforms
- **C++ core library**: Platform-specific builds, same source code
- **Isolation**: Each platform directory is independent
- **Testing**: Test each platform separately

When adding Windows/iOS/Android, follow the macOS implementation as a reference but adapt to platform-specific APIs and conventions.
