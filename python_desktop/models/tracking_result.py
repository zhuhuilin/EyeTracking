"""
TrackingResult data model - matches Flutter app's TrackingResult.
"""
from dataclasses import dataclass
from typing import Optional

@dataclass
class TrackingResult:
    """Real-time tracking data from computer vision engine."""

    face_distance: float
    gaze_angle_x: float
    gaze_angle_y: float
    eyes_focused: bool
    head_moving: bool
    shoulders_moving: bool
    face_detected: bool
    face_rect_x: float = 0.0
    face_rect_y: float = 0.0
    face_rect_width: float = 0.0
    face_rect_height: float = 0.0

    # Extended tracking data
    head_pose_pitch: float = 0.0
    head_pose_yaw: float = 0.0
    head_pose_roll: float = 0.0
    gaze_vector_x: float = 0.0
    gaze_vector_y: float = 0.0
    gaze_vector_z: float = 0.0
    confidence: float = 0.0

    def to_dict(self) -> dict:
        """Convert to dictionary for database storage."""
        return {
            "face_distance": self.face_distance,
            "gaze_angle_x": self.gaze_angle_x,
            "gaze_angle_y": self.gaze_angle_y,
            "eyes_focused": self.eyes_focused,
            "head_moving": self.head_moving,
            "shoulders_moving": self.shoulders_moving,
            "face_detected": self.face_detected,
            "face_rect_x": self.face_rect_x,
            "face_rect_y": self.face_rect_y,
            "face_rect_width": self.face_rect_width,
            "face_rect_height": self.face_rect_height,
            "head_pose_pitch": self.head_pose_pitch,
            "head_pose_yaw": self.head_pose_yaw,
            "head_pose_roll": self.head_pose_roll,
            "gaze_vector_x": self.gaze_vector_x,
            "gaze_vector_y": self.gaze_vector_y,
            "gaze_vector_z": self.gaze_vector_z,
            "confidence": self.confidence,
        }

    @staticmethod
    def empty() -> "TrackingResult":
        """Create an empty/default tracking result."""
        return TrackingResult(
            face_distance=0.0,
            gaze_angle_x=0.0,
            gaze_angle_y=0.0,
            eyes_focused=False,
            head_moving=False,
            shoulders_moving=False,
            face_detected=False,
        )
