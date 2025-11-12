# Eye Tracking App Improvements Summary

## Overview

This document summarizes the improvements made to address distance estimation accuracy, YuNet model verification, and YOLO CoreML integration.

## 1. Distance Estimation Accuracy Fix

### Issue
The legacy (Haar Cascade) model was estimating distances as 36-42cm when the actual distance was 72-78cm (approximately 50% too short).

### Root Cause
The default focal length was set to 1000.0 pixels, which was too low for accurate distance calculations.

### Solution
**File**: `/Users/huilinzhu/Projects/EyeTracking/core/src/tracking_engine.cpp:17`

Changed the default focal length from 1000.0 to 2000.0:

```cpp
TrackingEngine::TrackingEngine()
    : focal_length_(2000.0),  // Was 1000.0
```

### Formula
Distance calculation uses the pinhole camera model:
```
distance = (known_face_width * focal_length) / pixel_width
```

Where:
- `known_face_width` = 14.0 cm (average human face width)
- `focal_length` = 2000.0 pixels (calibrated for webcams)
- `pixel_width` = face detection width in pixels

### Testing
After rebuilding the C++ library, the distance should now read approximately 72-78cm at your actual distance. The library has been rebuilt and copied to:
- `/Users/huilinzhu/Projects/EyeTracking/core/install/macos/libeyeball_tracking_core.dylib`

## 2. YuNet Model Verification

### Debug Logging
The C++ code already includes comprehensive debug logging for YuNet model loading:

**File**: `/Users/huilinzhu/Projects/EyeTracking/core/src/tracking_engine.cpp:476-568`

Debug output includes:
- `[Tracking] Executable path: ...`
- `[Tracking] Executable dir: ...`
- `[Tracking] Trying X candidate paths for YuNet model...`
- `[Tracking] Found YuNet model at: ...` (if successful)
- `[Tracking] Loading YuNet face detector from: ...`
- `[Tracking] YuNet face detector loaded successfully`

### Verifying YuNet is Working

When you run the app and select "YuNet" backend, check the console for these messages:

1. **Model found**:
   ```
   [Tracking] Found YuNet model at: /path/to/face_detection_yunet_2023mar.onnx
   [Tracking] Loading YuNet face detector from: /path/to/face_detection_yunet_2023mar.onnx
   [Tracking] YuNet face detector loaded successfully
   ```

2. **Model not found**:
   ```
   [Tracking] No YuNet model found in any candidate path
   [Tracking] YuNet face detection model not found.
   ```

3. **Load error**:
   ```
   [Tracking] Failed to initialize YuNet face detector: <error message>
   [Tracking] Will fall back to alternative face detection methods
   ```

### Model Location
The YuNet model should be at:
```
/Users/huilinzhu/Projects/EyeTracking/flutter_app/macos/Runner/Resources/face_detection_yunet_2023mar.onnx
```

Size: 227 KB (valid model)

### If YuNet Doesn't Work

If you see "No YuNet model found" but the file exists:

1. **Check file permissions**:
   ```bash
   ls -lh /Users/huilinzhu/Projects/EyeTracking/flutter_app/macos/Runner/Resources/*.onnx
   ```

2. **Check OpenCV version** (requires OpenCV 4.6+):
   ```bash
   python3 -c "import cv2; print(cv2.__version__)"
   ```

3. **View full debug output**:
   ```bash
   flutter run -d macos 2>&1 | grep "\[Tracking\]"
   ```

## 3. YOLO CoreML Implementation

### Overview
Created a complete solution for converting YOLO models to CoreML format for macOS integration.

### Files Created

#### 1. Conversion Guide
**File**: `/Users/huilinzhu/Projects/EyeTracking/core/models/YOLO_COREML_CONVERSION.md`

Comprehensive guide covering:
- Prerequisites and installation
- Conversion process
- Model placement
- Integration notes
- Troubleshooting

#### 2. Conversion Script
**File**: `/Users/huilinzhu/Projects/EyeTracking/core/models/convert_yolo_to_coreml.py`

Automated Python script that:
- Checks dependencies
- Loads YOLO .pt model
- Converts to CoreML (.mlpackage format)
- Automatically copies to Flutter app Resources directory

**Usage**:
```bash
cd /Users/huilinzhu/Projects/EyeTracking/core/models
python3 convert_yolo_to_coreml.py yolo12m.pt
```

Or with custom settings:
```bash
python3 convert_yolo_to_coreml.py yolo12m.pt /output/dir 320
```

### Prerequisites

Install required packages:
```bash
pip3 install ultralytics coremltools torch torchvision
```

### Obtaining YOLO Model

**Option 1: Download pre-trained YOLO11**:
```bash
pip3 install ultralytics
python3 -c "from ultralytics import YOLO; YOLO('yolo11m.pt')"
```

**Option 2: Use YOLO12** (if you have yolo12m.pt):
Place the .pt file in the models directory and run the conversion script.

**Option 3: Face-specific YOLO**:
Search for "yolov8-face" or "YOLO-Face" models optimized for face detection.

### Integration

The Swift code already has CoreML YOLO integration:

**File**: `/Users/huilinzhu/Projects/EyeTracking/flutter_app/macos/Runner/EyeTrackingPlugin.swift`

The `CoreMLYoloDetector` class (referenced but not shown in snippets) handles:
- Loading .mlpackage models
- Processing camera frames
- Detecting faces with bounding boxes
- Passing detections to the C++ tracking engine

### Updated Podfile

**File**: `/Users/huilinzhu/Projects/EyeTracking/flutter_app/macos/Podfile:70-71`

Added support for copying CoreML model files during build:
```ruby
cp -rf "$SOURCE_DIR"/*.mlpackage "$RESOURCES_DIR/" 2>/dev/null || true
cp -rf "$SOURCE_DIR"/*.mlmodel "$RESOURCES_DIR/" 2>/dev/null || true
```

### Testing YOLO Integration

1. **Convert the model**:
   ```bash
   cd /Users/huilinzhu/Projects/EyeTracking/core/models
   python3 convert_yolo_to_coreml.py yolo12m.pt
   ```

2. **Rebuild the app**:
   ```bash
   cd /Users/huilinzhu/Projects/EyeTracking/flutter_app
   flutter clean
   flutter pub get
   flutter run -d macos
   ```

3. **Select YOLO backend** in the app UI

4. **Check console logs** for:
   ```
   [YOLO] CoreML detector initialized successfully
   ```

### Expected Model Locations

After conversion, models should be at:
```
/Users/huilinzhu/Projects/EyeTracking/flutter_app/macos/Runner/Resources/yolo12m.mlpackage/
/Users/huilinzhu/Projects/EyeTracking/flutter_app/macos/Runner/Resources/yolo11m.mlpackage/
```

## Summary of Changes

### C++ Code Changes
- `/Users/huilinzhu/Projects/EyeTracking/core/src/tracking_engine.cpp:17`
  - Changed `focal_length_` from 1000.0 to 2000.0

### New Files Created
1. `/Users/huilinzhu/Projects/EyeTracking/core/models/YOLO_COREML_CONVERSION.md` - Comprehensive guide
2. `/Users/huilinzhu/Projects/EyeTracking/core/models/convert_yolo_to_coreml.py` - Conversion script

### Modified Files
- `/Users/huilinzhu/Projects/EyeTracking/flutter_app/macos/Podfile:70-71`
  - Added CoreML model file copying

### Rebuilt Artifacts
- `/Users/huilinzhu/Projects/EyeTracking/core/install/macos/libeyeball_tracking_core.dylib`
  - Rebuilt with distance estimation fix

## Next Steps

1. **Test distance accuracy**:
   - Run the app with Legacy backend
   - Verify distance reads 72-78cm at your actual distance

2. **Test YuNet model**:
   - Select "YuNet" backend in the app
   - Check console for successful loading messages
   - Verify face detection works

3. **Implement YOLO (optional)**:
   - Obtain yolo12m.pt or yolo11m.pt
   - Run the conversion script
   - Rebuild and test with YOLO backend

## Troubleshooting

### Distance Still Incorrect
If the distance is still off:
1. Verify the rebuilt library is being used
2. Check if camera parameters are being set elsewhere
3. Consider adding calibration UI to allow users to adjust focal length

### YuNet Not Loading
1. Check model file exists and is 227KB (not a placeholder)
2. Verify OpenCV version supports YuNet (4.6+)
3. Review debug logs for specific error messages

### YOLO CoreML Issues
1. Ensure model is compiled (Xcode does this automatically)
2. Check macOS version compatibility
3. Try smaller model (yolo11n instead of yolo11m)

## Performance Comparison

Expected performance characteristics:

| Backend | Speed | Accuracy | CPU Usage |
|---------|-------|----------|-----------|
| Haar Cascade | Fastest | Good | Low |
| YuNet | Fast | Better | Medium |
| YOLO CoreML | Medium | Best | Medium-High (with Neural Engine) |

Choose based on your requirements:
- **Haar Cascade**: Best for battery life, acceptable accuracy
- **YuNet**: Good balance of speed and accuracy
- **YOLO**: Best accuracy, slightly higher resource usage
