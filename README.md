# EyeBall Tracking Application

A cross-platform eye and head tracking application for iOS, Android, macOS, and Windows.

## Features

- Real-time face distance measurement
- Eye tracking and gaze direction detection
- Head and shoulder movement detection
- Interactive testing with moving targets
- User authentication and data management
- Local and cloud storage options
- Admin dashboard for analytics

## Technology Stack

- **Frontend**: Flutter (Dart)
- **Computer Vision**: C++ with OpenCV and MediaPipe
- **Backend**: Node.js/Express (optional)
- **Database**: SQLite (local), PostgreSQL (cloud)
- **Authentication**: Firebase Auth or JWT

## Project Structure

```
eyeball_tracking/
├── core/                    # Shared C++ computer vision engine
├── flutter_app/             # Flutter UI application
├── backend/                 # Optional cloud backend
└── docs/                    # Documentation
```

## Setup Instructions

### Prerequisites

1. Install Flutter SDK with desktop support
2. Install OpenCV and MediaPipe for C++ core
3. Set up platform-specific development environments:
   - Android Studio for Android
   - Xcode for iOS
   - Visual Studio for Windows
   - Xcode for macOS

### Development

1. Clone the repository
2. Run `flutter pub get` in the `flutter_app` directory
3. Build the C++ core library
4. Run on target platform

## Build Instructions

### Mobile (iOS/Android)
```bash
cd flutter_app
flutter build apk
flutter build ios
```

### Desktop (macOS/Windows)
```bash
cd flutter_app
flutter build macos
flutter build windows
```

## License

MIT License
