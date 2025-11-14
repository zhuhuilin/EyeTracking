# Windows ARM64 Compatibility Notes

## Current Status

The Python desktop app is currently configured to work on **Windows ARM64** with the following limitations.

## Python Package Availability

### ✅ Working Packages (Windows ARM64)

- **Python 3.14**: Full support
- **NumPy**: Pre-built ARM64 wheels available
- **OpenCV (opencv-python)**: Pre-built ARM64 wheels available
- **PyQt6**: Pre-built ARM64 wheels available

### ❌ Unavailable Packages (Windows ARM64)

- **MediaPipe**: No ARM64 Windows support
  - Only available for: Windows x64, Linux, macOS
  - Python 3.12 support exists, but only for x64

- **Ultralytics (YOLO)**: Limited/no ARM64 Windows support

## Current Configuration

**Python Version**: 3.14
**Reason**: Best ARM64 package availability

### Installed Packages:
```
opencv-python 4.12.0  # Face detection with Haar Cascades
numpy 2.3.4           # Numerical operations
PyQt6 6.10.0          # GUI framework
```

### Face Detection Methods:
- ✅ **Haar Cascade**: Working (built into OpenCV)
- ✅ **OpenCV DNN** (with ONNX Runtime): Working for YOLO models
- ❌ **MediaPipe Face Mesh**: Not available

## Alternatives for Advanced Face Tracking

Since MediaPipe is not available, we use:

1. **Haar Cascade** - Fast, lightweight face detection
2. **OpenCV DNN + ONNX Runtime** - For YOLO face models
3. **OpenCV Eye Cascade** - For eye detection

## Python Version Compatibility Matrix

| Python | opencv-python ARM64 | mediapipe ARM64 | PyQt6 ARM64 |
|--------|-------------------|-----------------|-------------|
| 3.14   | ✅ Yes             | ❌ No           | ✅ Yes      |
| 3.13   | ✅ Yes             | ❌ No           | ✅ Yes      |
| 3.12   | ❌ No (build req) | ❌ No           | ✅ Yes      |
| 3.11   | ❌ No (build req) | ❌ No           | ✅ Yes      |

## Workarounds

### For MediaPipe Features:

If you need MediaPipe functionality:

1. **Use x64 Python** (runs under emulation on ARM64)
   - Install x64 Python from python.org
   - Slower performance but full package availability

2. **Build from Source** (complex)
   - Requires full Visual Studio ARM64 toolchain
   - Time-consuming and error-prone

3. **Use Cloud Processing**
   - Run CV processing on x64 server
   - Stream results to ARM64 client

### Recommended Approach

For now, **stick with the current setup** using:
- Python 3.14
- OpenCV Haar Cascades for face detection
- OpenCV Eye Cascades for eye tracking
- Custom gaze estimation algorithms

This provides:
- ✅ Native ARM64 performance
- ✅ No compilation required
- ✅ Reliable face and eye detection
- ✅ All core functionality working

## Future Improvements

Once MediaPipe adds ARM64 Windows support:
1. Update to Python 3.12
2. Add mediapipe to requirements.txt
3. Implement MediaPipe Face Mesh
4. Use MediaPipe's advanced pose estimation

## Testing

The current setup has been tested and works on:
- ✅ Windows 11 ARM64
- ✅ Surface Pro X / Surface Laptop (ARM64)

Monitor MediaPipe's GitHub for ARM64 Windows support:
https://github.com/google/mediapipe/issues
