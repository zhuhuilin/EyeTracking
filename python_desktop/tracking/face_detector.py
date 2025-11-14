"""
Face detection using Haar Cascade and YOLO.
"""
import cv2
import numpy as np
from pathlib import Path
from typing import Optional, Tuple
import config

class FaceDetector:
    """Face detection with multiple backend support."""

    def __init__(self, backend: str = "auto"):
        """
        Initialize face detector.

        Args:
            backend: "auto", "haar", or "yolo"
        """
        self.backend = backend
        self.haar_cascade: Optional[cv2.CascadeClassifier] = None
        self.yolo_model = None  # Placeholder for YOLO model
        self.active_backend = None

        self._initialize_detectors()

    def _initialize_detectors(self):
        """Initialize detection backends."""
        if self.backend in ("auto", "haar"):
            self._initialize_haar()

        if self.backend in ("auto", "yolo"):
            self._initialize_yolo()

        # Determine active backend
        if self.backend == "auto":
            if self.yolo_model is not None:
                self.active_backend = "yolo"
            elif self.haar_cascade is not None:
                self.active_backend = "haar"
            else:
                print("Warning: No face detection backend available")
                self.active_backend = None
        else:
            self.active_backend = self.backend

    def _initialize_haar(self):
        """Initialize Haar Cascade detector."""
        cascade_path = config.HAAR_CASCADE_PATH

        # Try to load from config path
        if Path(cascade_path).exists():
            self.haar_cascade = cv2.CascadeClassifier(cascade_path)
            if self.haar_cascade.empty():
                print(f"Warning: Failed to load Haar Cascade from {cascade_path}")
                self.haar_cascade = None
            else:
                print(f"Haar Cascade loaded from {cascade_path}")
                return

        # Fallback: try OpenCV's built-in cascade
        try:
            cascade_path = cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
            self.haar_cascade = cv2.CascadeClassifier(cascade_path)
            if not self.haar_cascade.empty():
                print(f"Haar Cascade loaded from OpenCV: {cascade_path}")
            else:
                self.haar_cascade = None
        except Exception as e:
            print(f"Warning: Failed to load Haar Cascade: {e}")
            self.haar_cascade = None

    def _initialize_yolo(self):
        """Initialize YOLO detector (placeholder for now)."""
        # TODO: Implement YOLO face detection using ultralytics
        # For now, YOLO is not implemented
        self.yolo_model = None
        print("YOLO face detection not yet implemented")

    def detect_face(self, frame: np.ndarray) -> Optional[Tuple[int, int, int, int]]:
        """
        Detect face in frame.

        Args:
            frame: Input frame (BGR format)

        Returns:
            Face bounding box as (x, y, width, height) or None if no face detected
        """
        if frame is None or frame.size == 0:
            return None

        if self.active_backend == "yolo" and self.yolo_model is not None:
            return self._detect_face_yolo(frame)
        elif self.active_backend == "haar" and self.haar_cascade is not None:
            return self._detect_face_haar(frame)
        else:
            return None

    def _detect_face_haar(self, frame: np.ndarray) -> Optional[Tuple[int, int, int, int]]:
        """Detect face using Haar Cascade."""
        if self.haar_cascade is None:
            return None

        # Convert to grayscale for Haar Cascade
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

        # Detect faces
        faces = self.haar_cascade.detectMultiScale(
            gray,
            scaleFactor=1.1,
            minNeighbors=5,
            minSize=(30, 30)
        )

        if len(faces) == 0:
            return None

        # Return the largest face
        largest_face = max(faces, key=lambda rect: rect[2] * rect[3])
        return tuple(largest_face)

    def _detect_face_yolo(self, frame: np.ndarray) -> Optional[Tuple[int, int, int, int]]:
        """Detect face using YOLO (placeholder)."""
        # TODO: Implement YOLO face detection
        return None

    def draw_face_box(self, frame: np.ndarray, face_rect: Tuple[int, int, int, int],
                     color: Tuple[int, int, int] = (0, 255, 0), thickness: int = 2):
        """
        Draw face bounding box on frame.

        Args:
            frame: Frame to draw on
            face_rect: Face rectangle (x, y, width, height)
            color: Box color in BGR
            thickness: Line thickness
        """
        x, y, w, h = face_rect
        cv2.rectangle(frame, (x, y), (x + w, y + h), color, thickness)

    def get_face_center(self, face_rect: Tuple[int, int, int, int]) -> Tuple[int, int]:
        """Get center point of face rectangle."""
        x, y, w, h = face_rect
        return (x + w // 2, y + h // 2)
