"""
Camera capture and frame management.
"""
import cv2
import numpy as np
from typing import Optional, Tuple
import config

class CameraCapture:
    """Manages camera capture and frame processing."""

    def __init__(self, camera_index: int = config.CAMERA_INDEX):
        self.camera_index = camera_index
        self.cap: Optional[cv2.VideoCapture] = None
        self.is_running = False

    def start(self) -> bool:
        """Initialize and start camera capture."""
        if self.is_running:
            return True

        self.cap = cv2.VideoCapture(self.camera_index)

        if not self.cap.isOpened():
            print(f"Failed to open camera {self.camera_index}")
            return False

        # Set camera properties
        self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, config.CAMERA_WIDTH)
        self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, config.CAMERA_HEIGHT)
        self.cap.set(cv2.CAP_PROP_FPS, config.CAMERA_FPS)

        self.is_running = True
        print(f"Camera {self.camera_index} started: {config.CAMERA_WIDTH}x{config.CAMERA_HEIGHT} @ {config.CAMERA_FPS} FPS")
        return True

    def stop(self):
        """Stop camera capture and release resources."""
        if self.cap:
            self.cap.release()
            self.cap = None
        self.is_running = False
        print("Camera stopped")

    def read_frame(self) -> Tuple[bool, Optional[np.ndarray]]:
        """
        Read a frame from the camera.

        Returns:
            Tuple of (success: bool, frame: Optional[np.ndarray])
        """
        if not self.is_running or not self.cap:
            return False, None

        ret, frame = self.cap.read()
        return ret, frame if ret else None

    def get_available_cameras(self) -> list:
        """Get list of available camera indices."""
        available = []
        for i in range(10):  # Check first 10 indices
            cap = cv2.VideoCapture(i)
            if cap.isOpened():
                available.append(i)
                cap.release()
        return available

    def switch_camera(self, camera_index: int) -> bool:
        """Switch to a different camera."""
        was_running = self.is_running
        if was_running:
            self.stop()

        self.camera_index = camera_index

        if was_running:
            return self.start()
        return True
