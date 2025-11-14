"""
Main tracking engine that coordinates camera, face detection, and eye tracking.
"""
import cv2
import numpy as np
from typing import Optional, Tuple
import config
from models import TrackingResult
from .camera import CameraCapture
from .face_detector import FaceDetector
from .eye_tracker import EyeTracker

class TrackingEngine:
    """
    Main tracking engine coordinating all CV operations.
    Matches the functionality of the C++ TrackingEngine.
    """

    def __init__(self):
        self.camera = CameraCapture()
        self.face_detector = FaceDetector(backend=config.FACE_DETECTOR_BACKEND)
        self.eye_tracker = EyeTracker()

        # Tracking state
        self.is_tracking = False
        self.calibrated = False

        # Camera parameters for distance calculation
        self.focal_length = config.FOCAL_LENGTH
        self.average_face_width_cm = config.AVERAGE_FACE_WIDTH_CM

        # Movement detection state
        self.previous_face_center: Optional[Tuple[int, int]] = None
        self.movement_threshold = 10  # pixels

        print("TrackingEngine initialized")

    def initialize(self) -> bool:
        """Initialize the tracking engine and camera."""
        success = self.camera.start()
        if success:
            print("TrackingEngine ready")
        return success

    def start_tracking(self):
        """Start tracking."""
        self.is_tracking = True
        print("Tracking started")

    def stop_tracking(self):
        """Stop tracking."""
        self.is_tracking = False
        print("Tracking stopped")

    def shutdown(self):
        """Shutdown and release resources."""
        self.stop_tracking()
        self.camera.stop()
        print("TrackingEngine shutdown")

    def process_frame(self, frame: Optional[np.ndarray] = None) -> Tuple[TrackingResult, Optional[np.ndarray]]:
        """
        Process a single frame and return tracking results.

        Args:
            frame: Optional frame to process. If None, reads from camera.

        Returns:
            Tuple of (TrackingResult, processed_frame)
        """
        # Read frame from camera if not provided
        if frame is None:
            if not self.is_tracking:
                return TrackingResult.empty(), None

            success, frame = self.camera.read_frame()
            if not success or frame is None:
                return TrackingResult.empty(), None

        # Create a copy for visualization
        display_frame = frame.copy()

        # Detect face
        face_rect = self.face_detector.detect_face(frame)

        if face_rect is None:
            # No face detected
            self.previous_face_center = None
            return TrackingResult.empty(), display_frame

        x, y, w, h = face_rect

        # Draw face box on display frame
        self.face_detector.draw_face_box(display_frame, face_rect)

        # Calculate face distance
        face_distance = self.calculate_face_distance(w)

        # Estimate gaze
        gaze_x, gaze_y = self.eye_tracker.estimate_gaze(frame, face_rect)

        # Check if eyes are focused
        eyes_focused = self.eye_tracker.are_eyes_focused(gaze_x, gaze_y)

        # Detect head movement
        face_center = self.face_detector.get_face_center(face_rect)
        head_moving = self.detect_movement(face_center)
        self.previous_face_center = face_center

        # Create tracking result
        result = TrackingResult(
            face_distance=face_distance,
            gaze_angle_x=gaze_x,
            gaze_angle_y=gaze_y,
            eyes_focused=eyes_focused,
            head_moving=head_moving,
            shoulders_moving=False,  # Not implemented yet
            face_detected=True,
            face_rect_x=float(x),
            face_rect_y=float(y),
            face_rect_width=float(w),
            face_rect_height=float(h),
            confidence=0.8,  # Simplified
        )

        # Draw tracking info on display frame
        self._draw_tracking_info(display_frame, result)

        return result, display_frame

    def calculate_face_distance(self, face_width_pixels: int) -> float:
        """
        Calculate distance from camera to face in cm.

        Uses pinhole camera model: distance = (real_width × focal_length) / pixel_width

        Args:
            face_width_pixels: Width of detected face in pixels

        Returns:
            Distance in cm
        """
        if face_width_pixels <= 0:
            return 0.0

        distance_cm = (self.average_face_width_cm * self.focal_length) / face_width_pixels
        return distance_cm

    def detect_movement(self, current_center: Tuple[int, int]) -> bool:
        """
        Detect if face/head has moved significantly.

        Args:
            current_center: Current face center (x, y)

        Returns:
            True if significant movement detected
        """
        if self.previous_face_center is None:
            return False

        prev_x, prev_y = self.previous_face_center
        curr_x, curr_y = current_center

        distance = np.sqrt((curr_x - prev_x)**2 + (curr_y - prev_y)**2)
        return distance > self.movement_threshold

    def _draw_tracking_info(self, frame: np.ndarray, result: TrackingResult):
        """Draw tracking information on frame."""
        h, w = frame.shape[:2]

        # Draw info panel background
        info_bg_height = 120
        overlay = frame.copy()
        cv2.rectangle(overlay, (0, 0), (w, info_bg_height), (0, 0, 0), -1)
        cv2.addWeighted(overlay, 0.5, frame, 0.5, 0, frame)

        # Text settings
        font = cv2.FONT_HERSHEY_SIMPLEX
        font_scale = 0.6
        color = (255, 255, 255)
        thickness = 1
        line_height = 25
        x_offset = 10

        # Display tracking metrics
        y_pos = 25
        cv2.putText(frame, f"Distance: {result.face_distance:.1f} cm",
                   (x_offset, y_pos), font, font_scale, color, thickness)

        y_pos += line_height
        cv2.putText(frame, f"Gaze X: {result.gaze_angle_x:.1f}deg  Y: {result.gaze_angle_y:.1f}deg",
                   (x_offset, y_pos), font, font_scale, color, thickness)

        y_pos += line_height
        status_text = "Eyes: "
        status_text += "FOCUSED" if result.eyes_focused else "NOT FOCUSED"
        status_color = (0, 255, 0) if result.eyes_focused else (0, 0, 255)
        cv2.putText(frame, status_text, (x_offset, y_pos), font, font_scale, status_color, thickness)

        y_pos += line_height
        movement_text = "Movement: "
        movement_text += "YES" if result.head_moving else "NO"
        cv2.putText(frame, movement_text, (x_offset, y_pos), font, font_scale, color, thickness)

    def start_calibration(self):
        """Start calibration process."""
        self.calibrated = False
        print("Calibration started")

    def finish_calibration(self):
        """Finish calibration process."""
        self.calibrated = True
        print("Calibration completed")

    def is_calibrated(self) -> bool:
        """Check if system is calibrated."""
        return self.calibrated

    def set_camera_parameters(self, focal_length: float, average_face_width: float = None):
        """Update camera parameters for distance calculation."""
        self.focal_length = focal_length
        if average_face_width is not None:
            self.average_face_width_cm = average_face_width
        print(f"Camera parameters updated: focal_length={focal_length}")
