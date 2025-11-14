"""
TestSession data model - matches Flutter app's TestSession.
"""
from dataclasses import dataclass, field
from datetime import datetime
from typing import List, Optional, Dict, Any
from enum import Enum

class TestType(Enum):
    """Test movement types."""
    RANDOM = "random"
    HORIZONTAL = "horizontal"
    VERTICAL = "vertical"

@dataclass
class TestConfiguration:
    """Configuration for a test session."""
    duration: int  # seconds
    test_type: TestType
    circle_size: int  # pixels
    movement_speed: int  # pixels per frame

    def to_dict(self) -> dict:
        return {
            "duration": self.duration,
            "test_type": self.test_type.value,
            "circle_size": self.circle_size,
            "movement_speed": self.movement_speed,
        }

@dataclass
class TestResults:
    """Calculated results from a test session."""
    accuracy: float  # 0.0 to 1.0
    reaction_time: float  # milliseconds
    movement_analysis: str
    overall_assessment: str

    def to_dict(self) -> dict:
        return {
            "accuracy": self.accuracy,
            "reaction_time": self.reaction_time,
            "movement_analysis": self.movement_analysis,
            "overall_assessment": self.overall_assessment,
        }

@dataclass
class TestSession:
    """Represents a complete test session with tracking data and results."""

    session_id: Optional[int]
    user_id: int
    configuration: TestConfiguration
    started_at: datetime
    completed_at: Optional[datetime] = None
    results: Optional[TestResults] = None
    tracking_data: List[Dict[str, Any]] = field(default_factory=list)

    def is_complete(self) -> bool:
        """Check if session is completed."""
        return self.completed_at is not None

    def add_tracking_point(self, tracking_result: Dict[str, Any],
                          target_x: float, target_y: float):
        """Add a tracking data point with target position."""
        self.tracking_data.append({
            "timestamp": datetime.now().isoformat(),
            "tracking": tracking_result,
            "target": {"x": target_x, "y": target_y},
        })

    def calculate_results(self) -> TestResults:
        """Calculate test results from tracking data."""
        if not self.tracking_data:
            return TestResults(
                accuracy=0.0,
                reaction_time=0.0,
                movement_analysis="No data",
                overall_assessment="Incomplete"
            )

        # Simple accuracy calculation based on gaze vs target distance
        total_error = 0.0
        valid_points = 0

        for point in self.tracking_data:
            tracking = point["tracking"]
            target = point["target"]

            if tracking.get("face_detected") and tracking.get("eyes_focused"):
                # Calculate distance between gaze and target
                # For now, simplified calculation
                gaze_x = tracking.get("gaze_angle_x", 0.0)
                gaze_y = tracking.get("gaze_angle_y", 0.0)

                # Normalize angles to screen coordinates (simplified)
                # This would need proper calibration in real implementation
                error = abs(gaze_x - target["x"]) + abs(gaze_y - target["y"])
                total_error += error
                valid_points += 1

        if valid_points == 0:
            accuracy = 0.0
        else:
            avg_error = total_error / valid_points
            # Convert error to accuracy (0-1 scale, lower error = higher accuracy)
            accuracy = max(0.0, 1.0 - (avg_error / 1000.0))

        # Calculate average reaction time (simplified)
        reaction_time = 250.0  # Placeholder

        # Generate assessment
        if accuracy > 0.8:
            assessment = "Excellent"
            analysis = "High accuracy tracking"
        elif accuracy > 0.6:
            assessment = "Good"
            analysis = "Moderate accuracy tracking"
        elif accuracy > 0.4:
            assessment = "Fair"
            analysis = "Room for improvement"
        else:
            assessment = "Poor"
            analysis = "Significant tracking issues detected"

        self.results = TestResults(
            accuracy=accuracy,
            reaction_time=reaction_time,
            movement_analysis=analysis,
            overall_assessment=assessment
        )

        return self.results

    def to_dict(self) -> dict:
        """Convert to dictionary for database storage."""
        return {
            "session_id": self.session_id,
            "user_id": self.user_id,
            "configuration": self.configuration.to_dict(),
            "started_at": self.started_at.isoformat(),
            "completed_at": self.completed_at.isoformat() if self.completed_at else None,
            "results": self.results.to_dict() if self.results else None,
            "tracking_data_count": len(self.tracking_data),
        }
