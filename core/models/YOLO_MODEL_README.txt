
YOLO Face Detection Model
=========================

The YOLO face detection model could not be automatically downloaded.

To manually download the model:

1. Visit: https://github.com/deepcam-cn/yolov5-face
2. Download the yolov5n-face.onnx model from the releases section
3. Place it in this directory (core/models/)

Or you can train/export your own model using:
- YOLOv8: pip install ultralytics && yolo export model=yolov8n.pt format=onnx
- YOLOv5-face: Follow instructions at https://github.com/deepcam-cn/yolov5-face

The tracking engine will automatically fall back to YuNet or Haar Cascade
if the YOLO model is not available.
