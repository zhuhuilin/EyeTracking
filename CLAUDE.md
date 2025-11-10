# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A cross-platform eye and head tracking application built with Flutter (frontend) and C++ with OpenCV/MediaPipe (computer vision backend). The application performs real-time face distance measurement, eye tracking, gaze direction detection, and head/shoulder movement detection. Users can run interactive tests with moving targets, and administrators can view analytics dashboards.

## Technology Stack

- **Frontend**: Flutter/Dart with Provider for state management
- **Computer Vision**: C++ with OpenCV (planned MediaPipe integration)
- **Platform Channels**: Method channels and event channels for Flutter-native communication
- **Storage**: SQLite (local), optional PostgreSQL (cloud)
- **Authentication**: Planned Firebase Auth or JWT
- **Platforms**: iOS, Android, macOS, Windows, Linux

## Development Commands

### Flutter App (from `flutter_app/` directory)

```bash
# Install dependencies
flutter pub get

# Run on default device
flutter run

# Run on specific platform
flutter run -d macos
flutter run -d windows
flutter run -d linux

# Run in debug/release mode
flutter run --debug
flutter run --release

# Testing
flutter test                      # Run unit tests
flutter test integration_test/    # Run integration tests
flutter test --coverage           # Run with coverage

# Building
flutter build apk                 # Android APK
flutter build appbundle           # Android App Bundle
flutter build ios                 # iOS
flutter build macos               # macOS
flutter build windows             # Windows
flutter build linux               # Linux

# Clean build artifacts
flutter clean
```

### C++ Core Library (from `core/` directory)

```bash
# Build for all platforms
chmod +x build.sh
./build.sh

# The build script automatically:
# - Checks dependencies (OpenCV, CMake)
# - Builds for Linux, macOS, Windows, Android, iOS
# - Generates Flutter platform channel bindings
# - Packages results in install/ directory
```

## Architecture

### Flutter Application Structure

```
flutter_app/lib/
├── main.dart                 # Entry point with Provider setup
├── app.dart                  # MaterialApp with routing logic
├── models/
│   └── app_state.dart        # Central state management (User, TestSession, TrackingResult, AppSettings)
├── services/
│   ├── camera_service.dart   # Camera initialization and tracking coordination
│   └── data_storage.dart     # SQLite and cloud storage abstraction
├── pages/
│   ├── login_page.dart       # User authentication UI
│   ├── home_page.dart        # Main interface for regular users
│   ├── calibration_page.dart # Eye tracking calibration
│   └── admin_dashboard.dart  # Admin analytics view
└── widgets/
    ├── circle_test_widget.dart          # Moving target test UI
    ├── test_configuration_dialog.dart   # Test settings dialog
    └── camera_selection_dialog.dart     # Camera picker
```

### State Management

The app uses Provider with `AppState` as the central state holder:
- **User management**: Current user, role (user/admin)
- **Test sessions**: Configuration, data points, results
- **Tracking state**: Real-time tracking results from camera service
- **Settings**: Cloud storage, analytics, processing quality

### Flutter-Native Communication

**Method Channels** (camera_service.dart):
- `eyeball_tracking/camera`: Commands to native code (initialize, start/stop tracking, process frames, calibration)

**Event Channels**:
- `eyeball_tracking/tracking`: Streaming tracking results from native to Flutter

**Native Integration Points**:
- macOS: `flutter_app/macos/Runner/EyeTrackingPlugin.swift` (and libeyeball_tracking_core.dylib)
- iOS: Platform-specific implementation needed
- Android: Platform-specific implementation needed

### Data Models

Key models in `app_state.dart`:
- `User`: id, email, role (user/admin), createdAt
- `TrackingResult`: Real-time tracking data (faceDistance, gazeAngleX/Y, eyesFocused, headMoving, shouldersMoving)
- `TestSession`: Test configuration, tracking data points, results calculation
- `TestConfiguration`: duration, type (random/horizontal/vertical), circleSize, movementSpeed
- `TestResults`: accuracy, reactionTime, movementAnalysis, overallAssessment

### Camera Service

`CameraService` (camera_service.dart:8-298):
- Manages camera initialization with configurable resolution (default: medium) and frame rate (30 fps)
- Supports multiple cameras with runtime switching
- Converts YUV420 camera frames to RGB for native processing
- Bridges Flutter camera plugin with native tracking engine via platform channels
- Includes `MockCameraService` for development without actual camera

### C++ Core

Located in `core/`:
- `CMakeLists.txt`: Build configuration linking OpenCV and platform-specific frameworks
- `build.sh`: Multi-platform build script (Linux, macOS, Windows, Android, iOS)
- Planned: `src/tracking_engine.cpp` and headers in `include/`
- Output: Shared libraries (.so, .dylib, .dll) and static libs (.a) for mobile

## Key Implementation Details

### Camera Frame Processing Flow

1. Flutter's camera plugin captures frames (YUV420 format)
2. `CameraService._processCameraImage()` converts to RGB using `_yuv420ToRgb()`
3. Frame data sent via method channel to native code
4. Native C++ processes with OpenCV/MediaPipe
5. Results streamed back via event channel
6. `AppState` updates with new `TrackingResult`

### Test Session Workflow

1. User configures test via `TestConfigurationDialog`
2. `AppState.startTestSession()` creates new `TestSession`
3. `CameraService.startTracking()` begins frame processing
4. Moving target displayed by `CircleTestWidget`
5. Each frame's tracking data linked with target position
6. On completion, `TestSession.calculateResults()` computes accuracy and metrics
7. Results stored via `DataStorage` (local SQLite or cloud)

### Authentication Flow

Conditional routing in `app.dart:20-28`:
- No user → `LoginPage`
- Admin user → `AdminDashboard`
- Regular user → `HomePage`

## Development Notes

### Camera Configuration

Modify resolution/frame rate in `camera_service.dart:24-25`:
```dart
static const ResolutionPreset _resolution = ResolutionPreset.medium;
static const int _frameRate = 30;
```

### Mock Camera Mode

For development without camera hardware, use `MockCameraService` which generates simulated tracking data.

### Platform-Specific Setup

**iOS**: Requires NSCameraUsageDescription in Info.plist

**Android**: Requires CAMERA permission and hardware.camera feature in AndroidManifest.xml

**Desktop**: Flutter desktop support must be enabled:
```bash
flutter config --enable-macos-desktop
flutter config --enable-windows-desktop
flutter config --enable-linux-desktop
```

### Build Dependencies

- Flutter SDK 3.0.0+
- OpenCV 4.8.0+ (for C++ core)
- CMake 3.16+
- Platform-specific: Xcode (iOS/macOS), Android Studio + NDK (Android), Visual Studio 2019+ (Windows)

## Common Workflows

### Adding New Tracking Metrics

1. Update `TrackingResult` model in `app_state.dart`
2. Modify native code to compute new metric
3. Update `_parseTrackingResult()` in `camera_service.dart` to parse new field
4. Update UI to display metric

### Implementing New Test Type

1. Add enum value to `TestType` in `app_state.dart`
2. Update `TestConfigurationDialog` to include new option
3. Modify `CircleTestWidget` to implement movement pattern
4. Update `TestSession.calculateResults()` if special scoring needed

### Platform Channel Debugging

Native method calls fail silently - check platform-specific logs:
- macOS: Console.app or `log stream --process Runner`
- iOS: Xcode console
- Android: `adb logcat`

## Storage Architecture

`DataStorage` service provides dual-mode storage:
- **Local**: SQLite via sqflite plugin for offline usage
- **Cloud**: HTTP API calls for server sync (configurable via `AppSettings.useCloudStorage`)

Sessions and user data automatically serialize to JSON via model `toJson()`/`fromJson()` methods.
