"""
Eye Tracking Desktop Prototype - Entry Point

A rapid prototype for eye and face tracking using Python + OpenCV + PyQt6.
"""
import sys
import traceback
from pathlib import Path

# Add project root to Python path
sys.path.insert(0, str(Path(__file__).parent))

import config
from database import Database
from gui import create_app

def main():
    """Main application entry point."""
    try:
        print("Starting Eye Tracking Desktop Prototype...")
        print(f"Database: {config.DATABASE_PATH}")
        print(f"Models directory: {config.MODELS_DIR}")
        print()

        # Ensure necessary directories exist
        config.ensure_directories()

        # Initialize database
        db = Database()
        db.connect()

        # Create and run PyQt6 application
        app = create_app(db)

        # Start Qt event loop
        sys.exit(app.exec())

    except Exception as e:
        print(f"\nERROR: Application failed to start!")
        print(f"Exception: {type(e).__name__}: {e}")
        print("\nFull traceback:")
        traceback.print_exc()
        print("\nPress Enter to exit...")
        input()
        sys.exit(1)

if __name__ == "__main__":
    main()
