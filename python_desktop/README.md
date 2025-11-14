# Eye Tracking Desktop Prototype (Python)

A rapid prototype for desktop eye and face tracking using Python + OpenCV.

## Quick Start

### Installation

```bash
# Create virtual environment
python -m venv venv

# Activate (Windows)
venv\Scripts\activate

# Activate (macOS/Linux)
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### Running

```bash
python main.py
```

## Architecture

```
python_desktop/
├── main.py                # Entry point
├── config.py              # Configuration management
├── database.py            # SQLite storage
├── tracking/
│   ├── __init__.py
│   ├── camera.py          # Camera capture
│   ├── face_detector.py   # Face detection (Haar, YOLO)
│   ├── eye_tracker.py     # Eye/gaze tracking
│   └── tracking_engine.py # Main tracking coordinator
├── gui/
│   ├── __init__.py
│   ├── app.py             # Main GUI application
│   ├── calibration.py     # Calibration UI
│   └── test_widget.py     # Moving target test UI
└── models/
    ├── __init__.py
    ├── tracking_result.py # TrackingResult data model
    ├── test_session.py    # TestSession data model
    └── user.py            # User data model
```

## Features

- Real-time face detection (Haar Cascade + YOLO)
- Eye tracking and gaze estimation
- Face distance calculation
- Calibration workflow
- Moving target tests
- SQLite data storage
- Cross-platform (Windows, macOS, Linux)

## Distribution

For end-users, package with PyInstaller:

```bash
pip install pyinstaller
pyinstaller --onefile --windowed main.py
```

This creates a standalone ~300-400 MB executable in `dist/`.

## Development Notes

- Uses Flet for Flutter-like UI development in Python
- OpenCV handles all CV operations (no build issues!)
- SQLite for local storage (same as Flutter app)
- Can share data models with Flutter mobile app later

## Next Steps

1. Implement core tracking engine
2. Build calibration UI
3. Add test workflows
4. Optimize performance
5. Consider Flutter mobile integration
