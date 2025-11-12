# YOLO CoreML Conversion Guide

This guide explains how to convert YOLO12m (YOLOv12) PyTorch model to CoreML format for use in the eye tracking app.

## Prerequisites

1. Python 3.8+ with pip
2. The yolo12m.pt model file
3. macOS (for CoreML conversion)

## Installation

Install required packages:

```bash
pip3 install ultralytics coremltools torch torchvision
```

## Conversion Script

Use the provided conversion script:

```bash
python3 convert_yolo_to_coreml.py yolo12m.pt
```

This will generate:
- `yolo12m.mlpackage` - CoreML model package
- `yolo12m.mlmodel` - Alternative CoreML format (if needed)

## Manual Conversion

If you want to convert manually:

```python
from ultralytics import YOLO
import coremltools as ct

# Load the YOLO model
model = YOLO('yolo12m.pt')

# Export to CoreML
model.export(format='coreml', nms=True, imgsz=640)
```

## Model Placement

After conversion, copy the `.mlpackage` to:

```bash
cp yolo12m.mlpackage /Users/huilinzhu/Projects/EyeTracking/flutter_app/macos/Runner/Resources/
```

## Integration Notes

The Swift code in `EyeTrackingPlugin.swift` already has CoreML YOLO integration via the `CoreMLYoloDetector` class. The detector expects:

- Model name: `yolo12m.mlpackage` or `yolo11m.mlpackage`
- Input: RGB image data
- Output: Face detections with bounding boxes

## Verification

After placing the model, run the app and select "YOLO" or "Auto" backend. Check console logs for:

```
[YOLO] CoreML detector initialized successfully
```

If there are errors, check:
1. Model file is in the correct location
2. Model was compiled during build (Xcode may compile .mlpackage automatically)
3. Model format is compatible with your macOS version

## Troubleshooting

### "Unable to load model" Error

The model needs to be compiled. Either:
1. Let Xcode compile it automatically during build, or
2. Compile manually:

```python
import coremltools as ct
model = ct.models.MLModel('yolo12m.mlpackage')
compiled_model_path = model.get_compiled_model_path()
print(f"Compiled to: {compiled_model_path}")
```

### Model Not Found

Ensure the Podfile post_install script copies .mlpackage files:

```ruby
cp -rf "$SOURCE_DIR"/*.mlpackage "$RESOURCES_DIR/" 2>/dev/null || true
```

### Performance Issues

For better performance, consider:
- Using smaller model (yolo12n or yolo12s)
- Reducing input size (from 640 to 320)
- Enabling GPU/Neural Engine acceleration in CoreML

## Alternative: YOLO11

If YOLO12 is not available or causes issues, YOLO11 works similarly:

```bash
pip3 install ultralytics
python3 -c "from ultralytics import YOLO; YOLO('yolo11m.pt').export(format='coreml', nms=True)"
```

The Swift code already checks for `yolo11m.mlpackage` as a fallback.

## Model Sources

- YOLOv11: https://docs.ultralytics.com/models/yolo11/
- YOLOv12 (if released): Check Ultralytics repository
- Pre-trained face detection: https://github.com/ultralytics/ultralytics

For face-specific YOLO models, consider:
- YOLOv8-face
- YOLO-Face (specialized for face detection)
