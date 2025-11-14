"""
Configuration management for the eye tracking application.
"""
import os
from pathlib import Path

# Project paths
PROJECT_ROOT = Path(__file__).parent
MODELS_DIR = PROJECT_ROOT / "assets" / "models"
DATABASE_PATH = PROJECT_ROOT / "eyetracking.db"

# Camera settings
CAMERA_INDEX = 0
CAMERA_WIDTH = 640
CAMERA_HEIGHT = 480
CAMERA_FPS = 30

# Face detection settings
FACE_DETECTOR_BACKEND = "auto"  # "auto", "haar", "yolo"
YOLO_MODEL_VARIANT = "n"  # "n" (nano), "s" (small), "m" (medium)
HAAR_CASCADE_PATH = str(MODELS_DIR / "haarcascade_frontalface_default.xml")
YOLO_MODEL_PATH = str(MODELS_DIR / f"yolov5{YOLO_MODEL_VARIANT}-face.pt")

# Detection thresholds
FACE_DETECTION_CONFIDENCE = 0.7
YOLO_CONF_THRESHOLD = 0.45
YOLO_NMS_THRESHOLD = 0.35

# Tracking settings
FOCAL_LENGTH = 2000.0  # Camera focal length (pixels)
AVERAGE_FACE_WIDTH_CM = 15.0  # Average human face width

# GUI settings
WINDOW_TITLE = "Eye Tracking Prototype"
WINDOW_WIDTH = 1280
WINDOW_HEIGHT = 720

# Test settings
TEST_DURATION_DEFAULT = 30  # seconds
CIRCLE_SIZE_DEFAULT = 50  # pixels
MOVEMENT_SPEED_DEFAULT = 5  # pixels per frame

# Database settings
DB_TIMEOUT = 30.0  # seconds

def ensure_directories():
    """Create necessary directories if they don't exist."""
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    (PROJECT_ROOT / "assets").mkdir(exist_ok=True)

def get_env(key: str, default=None):
    """Get environment variable with fallback."""
    return os.environ.get(key, default)
