# Quick Start Guide

Get the eye tracking prototype running in minutes!

## Prerequisites

- Python 3.8+ installed
- Webcam connected

## Installation

### 1. Create Virtual Environment

```bash
cd python_desktop
python -m venv venv
```

### 2. Activate Virtual Environment

**Windows:**
```bash
venv\Scripts\activate
```

**macOS/Linux:**
```bash
source venv/bin/activate
```

### 3. Install Dependencies

```bash
pip install -r requirements.txt
```

This will install:
- opencv-python (computer vision)
- flet (GUI framework)
- numpy (numerical operations)
- And other dependencies

**Note:** Installation may take 5-10 minutes as OpenCV is a large package.

## Running the App

```bash
python main.py
```

The application window will open showing:
- Live video feed from your webcam
- Face detection bounding box (green)
- Real-time tracking metrics
- Control buttons (Start/Stop/Calibrate)

## First Steps

1. Click **"Start Tracking"** to begin
2. Position your face in front of the camera
3. Watch the tracking info update in real-time:
   - Face Distance (cm)
   - Gaze angles
   - Eye focus status
   - Head movement detection

## Troubleshooting

### Camera Not Found

If you see "Failed to open camera":

```bash
# List available cameras
python -c "import cv2; print([i for i in range(10) if cv2.VideoCapture(i).isOpened()])"
```

Then update `config.py`:
```python
CAMERA_INDEX = 1  # Change to your camera index
```

### Import Errors

Make sure virtual environment is activated:
```bash
# Check if (venv) appears in your prompt
# If not, activate it again
venv\Scripts\activate  # Windows
source venv/bin/activate  # macOS/Linux
```

### Slow Performance

Reduce camera resolution in `config.py`:
```python
CAMERA_WIDTH = 320
CAMERA_HEIGHT = 240
```

## Next Steps

- Explore test sessions
- Try calibration (WIP)
- View tracking data in SQLite database: `eyetracking.db`

## Development

To add features:
- **Tracking logic**: Edit `tracking/tracking_engine.py`
- **GUI**: Edit `gui/app.py`
- **Models**: Edit files in `models/`
- **Config**: Edit `config.py`

Happy tracking!
