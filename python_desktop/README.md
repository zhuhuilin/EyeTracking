# Eye Tracking Desktop Prototype - Python + PyQt6

A rapid prototype for eye and face tracking using Python, OpenCV, and PyQt6.

## Quick Start

### Method 1: Double-click the batch file (Recommended)

1. Navigate to `python_desktop` folder in File Explorer
2. Double-click `run_app.bat`
3. The application window should appear

### Method 2: Run from PowerShell/Command Prompt

```cmd
cd python_desktop
venv\Scripts\python main.py
```

### Method 3: Run from Git Bash / MSYS2

```bash
cd python_desktop
venv/Scripts/python.exe main.py
```

## System Requirements

- **Platform**: Windows 11 ARM64
- **Python**: 3.14.0
- **Camera**: Integrated or USB webcam

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

- **Real-time face detection** using Haar Cascades
- **Eye tracking** and gaze estimation
- **Face distance** measurement
- **Head movement** detection
- **Live camera feed** visualization
- **PyQt6** modern desktop GUI with multi-threading
- **SQLite** data storage

## Application UI

The main window displays:

- **Video Feed**: Live camera view with face/eye detection overlays
- **Tracking Info Panel**: Real-time metrics
  - Face detected (Yes/No)
  - Distance from camera (cm)
  - Gaze angles (X/Y degrees)
  - Eyes focused indicator (color-coded green/red)
  - Head movement status
- **Control Buttons**:
  - Start Tracking
  - Stop Tracking
  - Calibrate (coming soon)

## Technical Details

### Face Detection
- Uses OpenCV Haar Cascade classifier
- Real-time detection at ~30 FPS
- Bounding box visualization with facial landmarks

### Eye Tracking
- Eye cascade detection within face region
- Gaze angle calculation (horizontal/vertical)
- Focus detection based on gaze stability

### Face Distance
- Calculated using pinhole camera model
- Based on detected face width
- Assumes average face width of 15cm

### Multi-threading
- Camera processing runs in background QThread
- UI updates via PyQt6 signals/slots
- Non-blocking interface ensuring smooth UI

## Windows ARM64 Compatibility

This app is specifically optimized for Windows ARM64:

- ✅ Python 3.14 with ARM64 wheels
- ✅ opencv-python (Haar Cascades working)
- ✅ PyQt6 native GUI
- ✅ NumPy ARM64
- ❌ MediaPipe not available (no ARM64 Windows support)

See [WINDOWS_ARM64.md](WINDOWS_ARM64.md) for full compatibility details.

## Troubleshooting

### Window doesn't appear or flashes briefly
- **Run from File Explorer**: Double-click `run_app.bat` instead of running from terminal
- **Interactive session required**: GUI apps need interactive Windows desktop session
- **Not via SSH/remote**: Don't run through remote terminal sessions
- **Check camera**: Verify camera permissions are granted in Windows Settings

### Camera not detected
- Verify camera is not in use by another application
- Check Device Manager for camera status
- Try changing camera index in `config.py` (CAMERA_INDEX = 0, 1, etc.)

### Import errors
- Ensure virtual environment exists: `python -m venv venv`
- Install dependencies: `venv\Scripts\pip install -r requirements.txt`

### Slow performance
- Reduce camera resolution in `config.py`
- Close other applications using the camera
- Check Task Manager for CPU usage

## Performance

- **Frame rate**: ~30 FPS
- **Face detection**: < 33ms per frame
- **Memory usage**: ~60-90 MB
- **CPU usage**: 5-10% (one core)

## Future Enhancements

- [ ] Calibration workflow implementation
- [ ] Moving target tests
- [ ] Test session recording and analysis
- [ ] Admin dashboard
- [ ] Cloud data sync
- [ ] ONNX Runtime integration for YOLO models
- [ ] MediaPipe integration (when ARM64 Windows support available)
