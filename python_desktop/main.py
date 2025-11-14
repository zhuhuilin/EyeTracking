"""
Eye Tracking Desktop Prototype - Entry Point

A rapid prototype for eye and face tracking using Python + OpenCV.
"""
import sys
import flet as ft
from pathlib import Path

# Add project root to Python path
sys.path.insert(0, str(Path(__file__).parent))

import config
from database import Database
from gui import EyeTrackingApp

def main(page: ft.Page):
    """Main Flet application entry point."""

    # Configure page
    page.title = config.WINDOW_TITLE
    page.window_width = config.WINDOW_WIDTH
    page.window_height = config.WINDOW_HEIGHT
    page.padding = 0
    page.theme_mode = ft.ThemeMode.LIGHT

    # Ensure necessary directories exist
    config.ensure_directories()

    # Initialize database
    db = Database()
    db.connect()

    # Create and start the app
    app = EyeTrackingApp(page, db)
    app.start()

def run():
    """Launch the Flet application."""
    print("Starting Eye Tracking Desktop Prototype...")
    print(f"Database: {config.DATABASE_PATH}")
    print(f"Models directory: {config.MODELS_DIR}")
    print()

    # Run Flet app
    ft.app(target=main)

if __name__ == "__main__":
    run()
