"""
Main Flet GUI application.
"""
import flet as ft
import cv2
import base64
import time
import threading
from typing import Optional
from models import User
from database import Database
from tracking import TrackingEngine

class EyeTrackingApp:
    """Main application UI."""

    def __init__(self, page: ft.Page, database: Database):
        self.page = page
        self.db = database
        self.tracking_engine = TrackingEngine()
        self.current_user: Optional[User] = None

        # UI components
        self.video_feed = ft.Image(
            width=640,
            height=480,
            fit=ft.ImageFit.CONTAIN,
        )

        self.status_text = ft.Text(
            "Initializing...",
            size=16,
            weight=ft.FontWeight.BOLD,
        )

        self.tracking_info = ft.Column(
            controls=[],
            spacing=10,
        )

        # Tracking thread
        self.tracking_thread: Optional[threading.Thread] = None
        self.running = False

    def start(self):
        """Start the application."""
        print("Starting application UI...")

        # Create demo user
        self._create_demo_user()

        # Build UI
        self._build_ui()

        # Initialize tracking engine
        if self.tracking_engine.initialize():
            self.status_text.value = "Ready - Click 'Start Tracking' to begin"
            self.page.update()
        else:
            self.status_text.value = "ERROR: Failed to initialize camera"
            self.page.update()

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

    def _build_ui(self):
        """Build the main UI."""
        # Control buttons
        start_button = ft.ElevatedButton(
            "Start Tracking",
            on_click=self._on_start_tracking,
            icon=ft.Icons.PLAY_ARROW,
        )

        stop_button = ft.ElevatedButton(
            "Stop Tracking",
            on_click=self._on_stop_tracking,
            icon=ft.Icons.STOP,
            disabled=True,
        )

        calibrate_button = ft.ElevatedButton(
            "Calibrate",
            on_click=self._on_calibrate,
            icon=ft.Icons.TUNE,
        )

        # Button row
        button_row = ft.Row(
            controls=[start_button, stop_button, calibrate_button],
            spacing=10,
        )

        # Store references
        self.start_button = start_button
        self.stop_button = stop_button

        # Main layout
        layout = ft.Column(
            controls=[
                ft.Container(
                    content=ft.Text(
                        "Eye Tracking Desktop Prototype",
                        size=24,
                        weight=ft.FontWeight.BOLD,
                    ),
                    padding=20,
                ),
                ft.Divider(),
                ft.Container(
                    content=self.status_text,
                    padding=10,
                ),
                ft.Row(
                    controls=[
                        ft.Container(
                            content=self.video_feed,
                            border=ft.border.all(2, ft.Colors.BLUE_400),
                            border_radius=10,
                        ),
                        ft.Container(
                            content=ft.Column(
                                controls=[
                                    ft.Text("Tracking Info", size=18, weight=ft.FontWeight.BOLD),
                                    ft.Divider(),
                                    self.tracking_info,
                                ],
                                width=300,
                            ),
                            padding=20,
                        ),
                    ],
                    alignment=ft.MainAxisAlignment.CENTER,
                    vertical_alignment=ft.CrossAxisAlignment.START,
                ),
                ft.Container(
                    content=button_row,
                    padding=20,
                ),
            ],
            scroll=ft.ScrollMode.AUTO,
            expand=True,
        )

        self.page.add(layout)

    def _on_start_tracking(self, e):
        """Handle start tracking button."""
        self.status_text.value = "Tracking active..."
        self.start_button.disabled = True
        self.stop_button.disabled = False
        self.page.update()

        # Start tracking
        self.running = True
        self.tracking_engine.start_tracking()

        # Start tracking thread
        self.tracking_thread = threading.Thread(target=self._tracking_loop, daemon=True)
        self.tracking_thread.start()

    def _on_stop_tracking(self, e):
        """Handle stop tracking button."""
        self.status_text.value = "Tracking stopped"
        self.start_button.disabled = False
        self.stop_button.disabled = True

        # Stop tracking
        self.running = False
        self.tracking_engine.stop_tracking()

        self.page.update()

    def _on_calibrate(self, e):
        """Handle calibrate button."""
        self.status_text.value = "Calibration not yet implemented"
        self.page.update()

    def _tracking_loop(self):
        """Main tracking loop running in background thread."""
        while self.running:
            try:
                # Process frame
                result, display_frame = self.tracking_engine.process_frame()

                if display_frame is not None:
                    # Convert frame to base64 for Flet display
                    _, buffer = cv2.imencode('.jpg', display_frame)
                    img_base64 = base64.b64encode(buffer).decode('utf-8')
                    self.video_feed.src_base64 = img_base64

                    # Update tracking info
                    self._update_tracking_info(result)

                    # Update UI
                    self.page.update()

                # Control frame rate
                time.sleep(1.0 / 30.0)  # ~30 FPS

            except Exception as ex:
                print(f"Error in tracking loop: {ex}")
                break

    def _update_tracking_info(self, result):
        """Update tracking information display."""
        self.tracking_info.controls = [
            ft.Text(f"Face Detected: {'Yes' if result.face_detected else 'No'}"),
            ft.Text(f"Distance: {result.face_distance:.1f} cm"),
            ft.Text(f"Gaze X: {result.gaze_angle_x:.1f}°"),
            ft.Text(f"Gaze Y: {result.gaze_angle_y:.1f}°"),
            ft.Text(
                f"Eyes Focused: {'Yes' if result.eyes_focused else 'No'}",
                color=ft.Colors.GREEN if result.eyes_focused else ft.Colors.RED,
            ),
            ft.Text(f"Head Moving: {'Yes' if result.head_moving else 'No'}"),
        ]
