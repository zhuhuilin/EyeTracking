"""
Eye tracking and gaze estimation (simplified implementation).
"""
import cv2
import numpy as np
from typing import Optional, Tuple

class EyeTracker:
    """Eye detection and gaze estimation."""

    def __init__(self):
        self.eye_cascade = None
        self._initialize_eye_detector()

    def _initialize_eye_detector(self):
        """Initialize eye cascade detector."""
        try:
            cascade_path = cv2.data.haarcascades + "haarcascade_eye.xml"
            self.eye_cascade = cv2.CascadeClassifier(cascade_path)
            if self.eye_cascade.empty():
                self.eye_cascade = None
                print("Warning: Failed to load eye cascade")
            else:
                print(f"Eye cascade loaded from {cascade_path}")
        except Exception as e:
            print(f"Warning: Failed to load eye cascade: {e}")
            self.eye_cascade = None

    def detect_eyes(self, face_roi: np.ndarray) -> list:
        """
        Detect eyes in face region of interest.

        Args:
            face_roi: Face region (grayscale or BGR)

        Returns:
            List of eye rectangles [(x, y, w, h), ...]
        """
        if self.eye_cascade is None or face_roi is None or face_roi.size == 0:
            return []

        # Convert to grayscale if needed
        if len(face_roi.shape) == 3:
            gray = cv2.cvtColor(face_roi, cv2.COLOR_BGR2GRAY)
        else:
            gray = face_roi

        # Detect eyes
        eyes = self.eye_cascade.detectMultiScale(
            gray,
            scaleFactor=1.1,
            minNeighbors=5,
            minSize=(20, 20)
        )

        return eyes.tolist() if len(eyes) > 0 else []

    def estimate_gaze(self, frame: np.ndarray, face_rect: Tuple[int, int, int, int]) -> Tuple[float, float]:
        """
        Estimate gaze direction (simplified).

        Args:
            frame: Full frame
            face_rect: Face bounding box (x, y, w, h)

        Returns:
            Tuple of (gaze_angle_x, gaze_angle_y) in degrees
        """
        x, y, w, h = face_rect

        # Extract face ROI
        face_roi = frame[y:y+h, x:x+w]

        # Detect eyes in face
        eyes = self.detect_eyes(face_roi)

        if len(eyes) >= 2:
            # Found both eyes - calculate gaze based on eye positions
            # This is a simplified calculation - real gaze estimation is much more complex

            # Sort eyes by x position (left to right)
            eyes = sorted(eyes, key=lambda e: e[0])
            left_eye = eyes[0]
            right_eye = eyes[1]

            # Calculate eye centers in face ROI coordinates
            left_center = (left_eye[0] + left_eye[2] // 2, left_eye[1] + left_eye[3] // 2)
            right_center = (right_eye[0] + right_eye[2] // 2, right_eye[1] + right_eye[3] // 2)

            # Calculate gaze direction (simplified - just eye position relative to face center)
            face_center_x = w // 2
            face_center_y = h // 2

            # Average eye position
            avg_eye_x = (left_center[0] + right_center[0]) // 2
            avg_eye_y = (left_center[1] + right_center[1]) // 2

            # Calculate angles (normalized to -30 to +30 degrees)
            gaze_x = ((avg_eye_x - face_center_x) / face_center_x) * 30.0
            gaze_y = ((avg_eye_y - face_center_y) / face_center_y) * 30.0

            return (gaze_x, gaze_y)

        # No eyes detected or insufficient data - return neutral gaze
        return (0.0, 0.0)

    def are_eyes_focused(self, gaze_x: float, gaze_y: float, threshold: float = 10.0) -> bool:
        """
        Determine if eyes are focused (looking at screen center).

        Args:
            gaze_x, gaze_y: Gaze angles in degrees
            threshold: Maximum angle deviation to consider "focused"

        Returns:
            True if eyes are focused on center
        """
        return abs(gaze_x) < threshold and abs(gaze_y) < threshold
