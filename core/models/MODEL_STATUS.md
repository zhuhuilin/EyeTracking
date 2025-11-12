# Face Detection Models Status

## Summary

All required face detection models have been set up and tested. The tracking engine now has proper error handling and graceful fallback between different detection backends.

## Model Status

### ✅ YuNet (Primary - Recommended)
- **Status**: ✓ Working
- **File**: `face_detection_yunet_2023mar.onnx` (227 KB)
- **Source**: OpenCV Model Zoo
- **Performance**: Fast and accurate, optimized for face detection
- **Location**:
  - `/core/models/face_detection_yunet_2023mar.onnx`
  - `/flutter_app/macos/Runner/Resources/face_detection_yunet_2023mar.onnx`

### ✅ Haar Cascade (Fallback - Legacy)
- **Status**: ✓ Working
- **File**: `haarcascade_frontalface_default.xml` (908 KB)
- **Source**: OpenCV built-in cascades
- **Performance**: Reliable but slower, good for compatibility
- **Location**:
  - `/core/models/haarcascade_frontalface_default.xml`
  - `/flutter_app/macos/Runner/Resources/haarcascade_frontalface_default.xml`

### ⚠️ YOLO Face Detection (Optional)
- **Status**: ✗ Not available (graceful fallback to YuNet/Haar Cascade)
- **File**: `yolov5n-face.onnx` (not present)
- **Performance**: Would be fastest if available
- **Note**: The application works without this model. If you want to add it:
  1. Download a YOLOv5 or YOLOv8 face detection model in ONNX format
  2. Place it as `core/models/yolov5n-face.onnx`
  3. Rebuild the library: `cd core/build && make`
  4. See `YOLO_MODEL_README.txt` for more details

### ✅ Eye Detection Cascade
- **Status**: ✓ Working
- **File**: `haarcascade_eye.xml` (765 KB)
- **Source**: OpenCV built-in cascades
- **Purpose**: Eye tracking and gaze estimation
- **Location**:
  - `/core/models/haarcascade_eye.xml`
  - `/flutter_app/macos/Runner/Resources/haarcascade_eye.xml`

## Backend Priority

The tracking engine uses the following priority order (when set to Auto):
1. **YOLO** (if available) - Fastest
2. **YuNet** (default) - Best balance of speed and accuracy
3. **Haar Cascade** (always available) - Most compatible

## Test Results

```
=== Face Detection Test Results ===
✓ YuNet: Face detected successfully
  Position: (0.406, 0.357)
  Size: 0.285 x 0.404

✓ Haar Cascade: Face detected successfully
  Position: (0.428, 0.396)
  Size: 0.330 x 0.330

✓ Auto (with fallback): Working
  Distance calculation: 95.89 cm
  Gaze tracking: Enabled
```

## Changes Made

### 1. Model Files
- Downloaded and installed YuNet ONNX model (227 KB)
- Copied Haar Cascade models from OpenCV installation
- Created placeholder for optional YOLO model

### 2. Code Improvements
- **tracking_engine.cpp**:
  - Improved model loading with multiple fallback paths
  - Added comprehensive error messages
  - Enhanced eye cascade loading with fallback paths
  - Better logging for debugging

- **CMakeLists.txt**:
  - Added compile-time definitions for model paths
  - Configured model installation paths
  - Added Haar Cascade to install targets

### 3. Build System
- Rebuilt C++ library with new model paths
- Copied library and models to Flutter app Resources directory
- All models properly bundled for macOS app

## How to Use

### Setting Backend Manually
```cpp
// From Swift/Flutter
set_face_detector_backend(engine, 0);  // Auto (recommended)
set_face_detector_backend(engine, 1);  // YOLO only
set_face_detector_backend(engine, 2);  // YuNet only
set_face_detector_backend(engine, 3);  // Haar Cascade only
```

### Environment Variables (Optional)
```bash
# Override model paths if needed
export EYETRACKING_FACE_MODEL=/path/to/yunet.onnx
export EYETRACKING_YOLO_FACE_MODEL=/path/to/yolo.onnx
export EYETRACKING_FACE_BACKEND=yunet  # or yolo, haar, auto
```

## Troubleshooting

### "Can't read ONNX file" error
- **YuNet**: The model file is present and working correctly
- **YOLO**: This is expected - YOLO model is optional, system falls back to YuNet

### Face not detected
1. Ensure good lighting conditions
2. Face should be clearly visible and frontal
3. Check that models are in Resources directory
4. Try different backends (YuNet usually works best)

### Models not found
- Check that models exist in:
  - `flutter_app/macos/Runner/Resources/` (for macOS app)
  - `core/models/` (for development/testing)
- Rebuild: `cd core/build && cmake .. && make`
- Copy to Flutter: `cp libeyeball_tracking_core.dylib ../../flutter_app/macos/Runner/`

## Next Steps (Optional)

### To add YOLO face detection:
1. Install ultralytics: `pip install ultralytics`
2. Export model:
   ```python
   from ultralytics import YOLO
   model = YOLO('yolov8n.pt')
   model.export(format='onnx', simplify=True)
   ```
3. Move `yolov8n.onnx` to `core/models/yolov5n-face.onnx`
4. Rebuild the library

## Files Modified
- `core/CMakeLists.txt` - Added model path definitions
- `core/src/tracking_engine.cpp` - Improved model loading and error handling
- `core/models/` - Added model files
- `flutter_app/macos/Runner/Resources/` - Bundled models for app
- `flutter_app/macos/Runner/libeyeball_tracking_core.dylib` - Updated library

## Conclusion

✅ **All required models are working correctly**
- YuNet (primary): Working
- Haar Cascade (fallback): Working
- YOLO (optional): Can be added later if needed

The eye tracking application is now ready to use with reliable face detection!
