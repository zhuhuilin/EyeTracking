# Platform-Specific Resource Management

This document explains how model files and resources are handled across different platforms.

## Overview

The eye tracking application uses ML models for face detection. Different platforms have different requirements for how these resources are bundled and loaded.

## Model Files

### Core Models (Platform-Independent)

Located in `core/models/`:
- `face_detection_yunet_2023mar.onnx` - YuNet face detection (ONNX format)
- `haarcascade_frontalface_default.xml` - Haar Cascade face detection
- `yolov5n-face.onnx` - YOLO face detection (ONNX format)

These are **ONNX** or **XML** formats compatible with all platforms.

### Platform-Specific Models

#### macOS/iOS Only
- `yolo11m.mlpackage` - CoreML format (Apple platforms only)
- Located in `flutter_app/macos/Runner/Resources/`
- Requires macOS 11+ or iOS 13+

#### Android
- Uses ONNX models from `core/models/`
- Bundled in APK `assets/` folder
- Loaded via AssetManager

#### Windows
- Uses ONNX models from `core/models/`
- Packaged as embedded resources or relative to executable

---

## Resource Loading Strategies by Platform

### Windows (x64 & ARM64)

**Build-time Path Configuration**:
```cmake
# In CMakeLists.txt
set(EYETRACKING_FACE_MODEL "${CMAKE_CURRENT_SOURCE_DIR}/models/face_detection_yunet_2023mar.onnx")
target_compile_definitions(eyeball_tracking_core PRIVATE
    EYETRACKING_DEFAULT_FACE_MODEL_PATH=\"${EYETRACKING_FACE_MODEL}\"
)
```

**Runtime Loading**:
1. Check compile-time default path
2. Fall back to path relative to DLL: `./models/`
3. Check user-specified path via environment variable: `EYETRACKING_MODEL_PATH`

**Installation**:
- Models are installed to `install/windows-{x64,arm64}/share/eyeball_tracking/models/`
- Flutter app copies models to app bundle during build

---

### macOS

**Build-time Configuration**:
- Models copied to app bundle `Resources/` folder
- Defined in `flutter_app/macos/Podfile`:
```ruby
post_install do |installer|
  # Copy model files to Resources
  system("cp", "-r", "#{models_path}/.", "#{resources_path}/")
end
```

**Runtime Loading**:
```swift
// In Swift code
let bundle = Bundle.main
if let modelPath = bundle.path(forResource: "face_detection_yunet_2023mar", ofType: "onnx") {
    // Use modelPath
}
```

**Special Case - CoreML**:
- CoreML models (`.mlpackage`) are macOS/iOS specific
- Used for optimized inference on Apple Silicon
- Falls back to ONNX if CoreML unavailable

---

### iOS

**Build-time Configuration**:
- Models added to Xcode project as resources
- Automatically bundled in app `.ipa`

**Runtime Loading**:
```swift
let bundle = Bundle.main
guard let modelPath = bundle.path(forResource: "face_detection_yunet_2023mar", ofType: "onnx") else {
    fatalError("Model not found in bundle")
}
```

**Recommendations**:
- Use `.mlpackage` (CoreML) for best performance on iOS
- Keep `.onnx` as fallback
- Models should be < 50MB to avoid app size issues

---

### Android

**Build-time Configuration**:
- Models placed in `flutter_app/android/app/src/main/assets/models/`
- Automatically included in APK

**Runtime Loading (JNI)**:
```cpp
// In C++ JNI code
AAssetManager* assetManager = // ... get from Java
AAsset* asset = AAssetManager_open(assetManager, "models/face_detection_yunet_2023mar.onnx", AASSET_MODE_BUFFER);
// Read asset data
```

**Size Considerations**:
- Models are compressed in APK
- Total asset size should be < 100MB for Play Store
- Consider downloading large models on first run

---

## Model Format Compatibility

| Format | Windows | macOS | iOS | Android | Size | Performance |
|--------|---------|-------|-----|---------|------|-------------|
| `.onnx` | ✅ | ✅ | ✅ | ✅ | Medium | Good |
| `.mlpackage` (CoreML) | ❌ | ✅ | ✅ | ❌ | Medium | Excellent (Apple) |
| `.tflite` | ✅ | ✅ | ✅ | ✅ | Small | Good (mobile) |
| `.xml` (Haar) | ✅ | ✅ | ✅ | ✅ | Small | Fast (simple) |

**Recommendations**:
- **Primary**: Use ONNX for cross-platform compatibility
- **iOS/macOS**: Use CoreML for best performance
- **Android**: Consider TFLite for smaller app size
- **All**: Haar Cascades as lightweight fallback

---

## Adding New Models

### 1. Choose Format

**Cross-platform app?** → Use ONNX
**iOS/macOS only?** → Use CoreML
**Android focus?** → Use TFLite
**Simple detection?** → Use Haar Cascade XML

### 2. Place Model Files

**Core C++ models**:
```
core/models/
└── your_model.onnx
```

**Platform-specific models**:
```
flutter_app/
├── macos/Runner/Resources/
│   └── your_model.mlpackage/
├── android/app/src/main/assets/models/
│   └── your_model.tflite
└── ios/Runner/Resources/
    └── your_model.mlpackage/
```

### 3. Update Build Configuration

**For core models** - Update `core/CMakeLists.txt`:
```cmake
set(YOUR_MODEL "${CMAKE_CURRENT_SOURCE_DIR}/models/your_model.onnx")
target_compile_definitions(eyeball_tracking_core PRIVATE
    YOUR_MODEL_PATH=\"${YOUR_MODEL}\"
)

install(FILES models/your_model.onnx
        DESTINATION share/eyeball_tracking/models)
```

**For Flutter resources** - Update platform build files:
- macOS: `flutter_app/macos/Podfile`
- iOS: Add to Xcode project
- Android: Place in `assets/` (auto-included)
- Windows: Update package script

### 4. Update Code

Add model loading logic in `core/src/tracking_engine.cpp`:
```cpp
std::string getModelPath(const std::string& default_path) {
    // Try environment variable first
    if (const char* env_path = std::getenv("EYETRACKING_MODEL_PATH")) {
        return std::string(env_path);
    }
    // Use default compiled-in path
    return default_path;
}
```

---

## Environment Variables

You can override default model paths using environment variables:

| Variable | Purpose | Example |
|----------|---------|---------|
| `EYETRACKING_MODEL_PATH` | Base path for models | `/custom/path/to/models/` |
| `EYETRACKING_FACE_BACKEND` | Preferred detection backend | `YOLO`, `YuNet`, or `HaarCascade` |

**Usage**:
```bash
# macOS/Linux
export EYETRACKING_MODEL_PATH="/path/to/models"
export EYETRACKING_FACE_BACKEND="YuNet"

# Windows
set EYETRACKING_MODEL_PATH=C:\path\to\models
set EYETRACKING_FACE_BACKEND=YuNet
```

---

## Troubleshooting

### Model Not Found

**Symptoms**: `Model file not found` error at runtime

**Solutions**:
1. Verify model exists in expected location
2. Check file permissions
3. Try absolute path instead of relative
4. Set `EYETRACKING_MODEL_PATH` environment variable
5. Check build logs to ensure model was installed

### Wrong Model Format

**Symptoms**: `Failed to load model` or format errors

**Solutions**:
1. Verify you're using correct format for platform:
   - Windows/macOS/Linux: ONNX works
   - macOS/iOS only: CoreML works
   - Android: ONNX or TFLite works
2. Check OpenCV DNN module supports your model format
3. Try converting model to ONNX (most compatible)

### Model Too Large

**Symptoms**: App size exceeds store limits, slow loading

**Solutions**:
1. Use quantized models (INT8 instead of FP32)
2. Download models on first run (not bundled)
3. Use smaller model variants (e.g., YOLOv5n instead of YOLOv5m)
4. Compress models before bundling

---

## Best Practices

1. **Always provide fallback**: Include lightweight Haar Cascade as fallback
2. **Test on target device**: Model performance varies by platform/hardware
3. **Version control**: Include model version in filename
4. **Document requirements**: Note minimum OS version for CoreML/TFLite features
5. **Size constraints**: Keep total models < 50MB when possible
6. **License compliance**: Verify model licenses allow redistribution

---

## Summary

- **ONNX models**: Universal, stored in `core/models/`
- **Platform-specific formats**: CoreML (Apple), TFLite (Android)
- **Loading**: Compile-time paths with runtime overrides
- **Installation**: Platform-specific bundling strategies
- **Best practice**: ONNX primary, platform-optimized secondary
