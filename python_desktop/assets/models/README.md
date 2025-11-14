# Model Files

This directory stores face detection models.

## Required Models

### Haar Cascade (Built-in with OpenCV)
- **haarcascade_frontalface_default.xml** - OpenCV's built-in face detector
- Automatically loaded from OpenCV installation
- No download required

### YOLO Face Detection (Optional)
- **yolov5n-face.pt** - Nano variant (smallest, fastest)
- **yolov5s-face.pt** - Small variant
- **yolov5m-face.pt** - Medium variant (default)

Download from: https://github.com/deepcam-cn/yolov5-face/releases

For rapid prototyping, start with Haar Cascade (no download needed).

## Installation

```bash
# Haar Cascade - already included with opencv-python, no action needed

# For YOLO (optional):
# 1. Download model file (e.g., yolov5m-face.pt)
# 2. Place in this directory
# 3. Update config.py YOLO_MODEL_VARIANT if needed
```
