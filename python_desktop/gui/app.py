"""
Main PyQt6 GUI application.
"""
import sys
import cv2
import numpy as np
from typing import Optional
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QPushButton, QLabel, QFrame, QGroupBox
)
from PyQt6.QtCore import QTimer, Qt, pyqtSignal, QThread
from PyQt6.QtGui import QImage, QPixmap, QFont
from models import User, TrackingResult
from database import Database
from tracking import TrackingEngine


class TrackingThread(QThread):
    """Background thread for camera tracking."""

    frame_ready = pyqtSignal(np.ndarray, TrackingResult)

    def __init__(self, tracking_engine: TrackingEngine):
        super().__init__()
        self.tracking_engine = tracking_engine
        self.running = False

    def run(self):
        """Main tracking loop."""
        self.running = True
        while self.running:
            result, display_frame = self.tracking_engine.process_frame()
            if display_frame is not None:
                self.frame_ready.emit(display_frame, result)
            self.msleep(33)  # ~30 FPS

    def stop(self):
        """Stop the tracking thread."""
        self.running = False


class EyeTrackingApp(QMainWindow):
    """Main application window."""

    def __init__(self, database: Database):
        super().__init__()
        self.db = database
        self.tracking_engine = TrackingEngine()
        self.current_user: Optional[User] = None
        self.tracking_thread: Optional[TrackingThread] = None

        # Create demo user
        self._create_demo_user()

        # Initialize UI
        self._init_ui()

        # Initialize tracking engine
        if self.tracking_engine.initialize():
            self.status_label.setText("Ready - Click 'Start Tracking' to begin")
        else:
            self.status_label.setText("ERROR: Failed to initialize camera")

    def _create_demo_user(self):
        """Create a demo user for testing."""
        user_data = self.db.get_user("demo@example.com")
        if user_data is None:
            user_id = self.db.create_user("demo@example.com", "user")
            self.current_user = User(
                id=user_id,
                email="demo@example.com",
                role="user"
            )
        else:
            self.current_user = User.from_dict(user_data)

        print(f"Current user: {self.current_user.email} (ID: {self.current_user.id})")

    def _init_ui(self):
        """Initialize the user interface."""
        self.setWindowTitle("Eye Tracking Desktop Prototype")
        self.setGeometry(100, 100, 1280, 720)

        # Center window on primary screen
        from PyQt6.QtGui import QScreen
        screen = QScreen.availableGeometry(self.screen())
        x = (screen.width() - 1280) // 2
        y = (screen.height() - 720) // 2
        self.move(x, y)

        # Bring window to front on startup
        self.raise_()
        self.activateWindow()

        # Central widget
        central_widget = QWidget()
        self.setCentralWidget(central_widget)

        # Main layout
        main_layout = QVBoxLayout(central_widget)
        main_layout.setContentsMargins(20, 20, 20, 20)
        main_layout.setSpacing(15)

        # Title
        title_label = QLabel("Eye Tracking Desktop Prototype")
        title_font = QFont()
        title_font.setPointSize(18)
        title_font.setBold(True)
        title_label.setFont(title_font)
        main_layout.addWidget(title_label)

        # Status label
        self.status_label = QLabel("Initializing...")
        self.status_label.setStyleSheet("padding: 10px; background-color: #f0f0f0; border-radius: 5px;")
        main_layout.addWidget(self.status_label)

        # Content area (video + info panel)
        content_layout = QHBoxLayout()
        content_layout.setSpacing(20)

        # Video feed
        video_frame = QFrame()
        video_frame.setFrameStyle(QFrame.Shape.Box | QFrame.Shadow.Raised)
        video_frame.setLineWidth(2)
        video_layout = QVBoxLayout(video_frame)

        self.video_label = QLabel()
        self.video_label.setFixedSize(640, 480)
        self.video_label.setStyleSheet("background-color: black;")
        self.video_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        video_layout.addWidget(self.video_label)

        content_layout.addWidget(video_frame)

        # Info panel
        info_group = QGroupBox("Tracking Info")
        info_layout = QVBoxLayout(info_group)
        info_layout.setSpacing(10)

        self.face_detected_label = QLabel("Face Detected: No")
        self.distance_label = QLabel("Distance: -- cm")
        self.gaze_x_label = QLabel("Gaze X: --°")
        self.gaze_y_label = QLabel("Gaze Y: --°")
        self.eyes_focused_label = QLabel("Eyes Focused: No")
        self.head_moving_label = QLabel("Head Moving: No")

        for label in [self.face_detected_label, self.distance_label,
                     self.gaze_x_label, self.gaze_y_label,
                     self.eyes_focused_label, self.head_moving_label]:
            label.setStyleSheet("padding: 5px; font-size: 12pt;")
            info_layout.addWidget(label)

        info_layout.addStretch()
        info_group.setFixedWidth(300)
        content_layout.addWidget(info_group)

        main_layout.addLayout(content_layout)

        # Control buttons
        button_layout = QHBoxLayout()
        button_layout.setSpacing(10)

        self.start_button = QPushButton("Start Tracking")
        self.start_button.setFixedHeight(40)
        self.start_button.setStyleSheet("""
            QPushButton {
                background-color: #4CAF50;
                color: white;
                font-size: 14pt;
                border-radius: 5px;
                padding: 5px 15px;
            }
            QPushButton:hover {
                background-color: #45a049;
            }
            QPushButton:disabled {
                background-color: #cccccc;
            }
        """)
        self.start_button.clicked.connect(self._on_start_tracking)

        self.stop_button = QPushButton("Stop Tracking")
        self.stop_button.setFixedHeight(40)
        self.stop_button.setEnabled(False)
        self.stop_button.setStyleSheet("""
            QPushButton {
                background-color: #f44336;
                color: white;
                font-size: 14pt;
                border-radius: 5px;
                padding: 5px 15px;
            }
            QPushButton:hover {
                background-color: #da190b;
            }
            QPushButton:disabled {
                background-color: #cccccc;
            }
        """)
        self.stop_button.clicked.connect(self._on_stop_tracking)

        self.calibrate_button = QPushButton("Calibrate")
        self.calibrate_button.setFixedHeight(40)
        self.calibrate_button.setStyleSheet("""
            QPushButton {
                background-color: #2196F3;
                color: white;
                font-size: 14pt;
                border-radius: 5px;
                padding: 5px 15px;
            }
            QPushButton:hover {
                background-color: #0b7dda;
            }
        """)
        self.calibrate_button.clicked.connect(self._on_calibrate)

        button_layout.addWidget(self.start_button)
        button_layout.addWidget(self.stop_button)
        button_layout.addWidget(self.calibrate_button)
        button_layout.addStretch()

        main_layout.addLayout(button_layout)

    def _on_start_tracking(self):
        """Handle start tracking button."""
        self.status_label.setText("Tracking active...")
        self.start_button.setEnabled(False)
        self.stop_button.setEnabled(True)

        # Start tracking engine
        self.tracking_engine.start_tracking()

        # Start tracking thread
        self.tracking_thread = TrackingThread(self.tracking_engine)
        self.tracking_thread.frame_ready.connect(self._update_frame)
        self.tracking_thread.start()

    def _on_stop_tracking(self):
        """Handle stop tracking button."""
        self.status_label.setText("Tracking stopped")
        self.start_button.setEnabled(True)
        self.stop_button.setEnabled(False)

        # Stop tracking thread
        if self.tracking_thread:
            self.tracking_thread.stop()
            self.tracking_thread.wait()
            self.tracking_thread = None

        # Stop tracking engine
        self.tracking_engine.stop_tracking()

        # Clear video feed
        self.video_label.clear()
        self.video_label.setText("Stopped")

    def _on_calibrate(self):
        """Handle calibrate button."""
        self.status_label.setText("Calibration not yet implemented")

    def _update_frame(self, frame: np.ndarray, result: TrackingResult):
        """Update video frame and tracking info."""
        # Convert frame to QPixmap
        height, width, channel = frame.shape
        bytes_per_line = 3 * width
        q_image = QImage(frame.data, width, height, bytes_per_line, QImage.Format.Format_RGB888)
        q_image = q_image.rgbSwapped()  # BGR to RGB
        pixmap = QPixmap.fromImage(q_image)

        # Scale to fit label
        scaled_pixmap = pixmap.scaled(
            self.video_label.size(),
            Qt.AspectRatioMode.KeepAspectRatio,
            Qt.TransformationMode.SmoothTransformation
        )
        self.video_label.setPixmap(scaled_pixmap)

        # Update tracking info
        self.face_detected_label.setText(
            f"Face Detected: {'Yes' if result.face_detected else 'No'}"
        )
        self.distance_label.setText(f"Distance: {result.face_distance:.1f} cm")
        self.gaze_x_label.setText(f"Gaze X: {result.gaze_angle_x:.1f}°")
        self.gaze_y_label.setText(f"Gaze Y: {result.gaze_angle_y:.1f}°")

        # Eyes focused with color
        if result.eyes_focused:
            self.eyes_focused_label.setText("Eyes Focused: Yes")
            self.eyes_focused_label.setStyleSheet("padding: 5px; font-size: 12pt; color: green; font-weight: bold;")
        else:
            self.eyes_focused_label.setText("Eyes Focused: No")
            self.eyes_focused_label.setStyleSheet("padding: 5px; font-size: 12pt; color: red;")

        self.head_moving_label.setText(
            f"Head Moving: {'Yes' if result.head_moving else 'No'}"
        )

    def closeEvent(self, event):
        """Handle window close event."""
        # Stop tracking if running
        if self.tracking_thread:
            self.tracking_thread.stop()
            self.tracking_thread.wait()

        # Shutdown tracking engine
        self.tracking_engine.shutdown()

        event.accept()


def create_app(database: Database) -> QApplication:
    """Create and configure the PyQt6 application."""
    app = QApplication(sys.argv)
    app.setStyle("Fusion")  # Modern look

    window = EyeTrackingApp(database)

    # CRITICAL: Store window as app attribute to prevent garbage collection
    app.main_window = window

    window.show()

    return app
