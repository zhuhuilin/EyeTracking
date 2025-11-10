# EyeBall Tracking - Deployment Guide

This guide provides comprehensive instructions for building, testing, and deploying the EyeBall Tracking application across all supported platforms.

## Prerequisites

### Required Software

1. **Flutter SDK** (3.0.0 or later)
   ```bash
   # Install Flutter with desktop support
   flutter channel stable
   flutter upgrade
   flutter config --enable-macos-desktop
   flutter config --enable-windows-desktop
   flutter config --enable-linux-desktop
   ```

2. **OpenCV 4.8.0+**
   - **macOS**: `brew install opencv`
   - **Ubuntu**: `sudo apt-get install libopencv-dev`
   - **Windows**: Download from OpenCV.org

3. **Platform-Specific Tools**
   - **iOS**: Xcode 14.0+
   - **Android**: Android Studio, Android SDK, NDK
   - **Windows**: Visual Studio 2019+
   - **macOS**: Xcode command line tools

## Build Process

### Step 1: Build C++ Core Library

```bash
cd eyeball_tracking/core
chmod +x build.sh
./build.sh
```

This will build the computer vision core for all platforms and generate Flutter bindings.

### Step 2: Build Flutter Application

```bash
cd eyeball_tracking/flutter_app

# Install dependencies
flutter pub get

# Build for specific platforms
flutter build apk          # Android
flutter build appbundle    # Android App Bundle
flutter build ios          # iOS
flutter build macos        # macOS
flutter build windows      # Windows
flutter build linux        # Linux
```

### Step 3: Platform-Specific Setup

#### iOS Setup
1. Open `ios/Runner.xcworkspace` in Xcode
2. Configure signing and provisioning profiles
3. Add camera permissions to `Info.plist`:
   ```xml
   <key>NSCameraUsageDescription</key>
   <string>This app needs camera access for eye tracking</string>
   ```

#### Android Setup
1. Ensure `android/app/src/main/AndroidManifest.xml` includes:
   ```xml
   <uses-permission android:name="android.permission.CAMERA" />
   <uses-feature android:name="android.hardware.camera" />
   <uses-feature android:name="android.hardware.camera.autofocus" />
   ```

#### Desktop Setup
For desktop platforms, ensure Flutter desktop support is enabled and platform-specific dependencies are installed.

## Development Environment

### Running the Application

```bash
# Run on connected device/emulator
flutter run

# Run on specific platform
flutter run -d windows
flutter run -d macos
flutter run -d linux

# Run in debug mode
flutter run --debug

# Run in release mode
flutter run --release
```

### Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/

# Run with coverage
flutter test --coverage
```

## Deployment

### App Store Deployment

#### iOS (App Store)
1. Build for release: `flutter build ios --release`
2. Archive in Xcode
3. Upload to App Store Connect
4. Submit for review

#### Android (Google Play)
1. Build App Bundle: `flutter build appbundle`
2. Create release in Google Play Console
3. Upload the .aab file
4. Submit for review

### Desktop Deployment

#### macOS
```bash
flutter build macos --release
# Output: build/macos/Build/Products/Release/eyeball_tracking.app
```

#### Windows
```bash
flutter build windows --release
# Output: build/windows/runner/Release/
```

#### Linux
```bash
flutter build linux --release
# Output: build/linux/x64/release/bundle/
```

## Configuration

### Environment Variables

Create a `.env` file in the flutter_app directory:
```env
# Cloud storage configuration
CLOUD_API_URL=https://api.eyeballtracking.com
CLOUD_API_KEY=your_api_key_here

# Analytics (optional)
ANALYTICS_ENABLED=true
ANALYTICS_ID=your_analytics_id

# Development flags
USE_MOCK_CAMERA=false
ENABLE_DEBUG_LOGS=true
```

### Camera Configuration

The application supports different camera configurations:

```dart
// In camera_service.dart
static const ResolutionPreset _resolution = ResolutionPreset.medium;
static const int _frameRate = 30;
```

Adjust these values based on performance requirements and device capabilities.

## Performance Optimization

### Build Optimization

```bash
# Build with performance optimizations
flutter build apk --split-per-abi --target-platform android-arm,android-arm64
flutter build ios --no-codesign --tree-shake-icons
```

### Code Optimization

1. **Enable tree shaking**: Remove unused code
2. **Use AOT compilation**: For release builds
3. **Optimize images**: Use WebP format when possible
4. **Minimize plugin usage**: Only include necessary plugins

## Troubleshooting

### Common Issues

1. **Camera Permissions**
   - Ensure permissions are properly configured for each platform
   - Test on real devices for permission flows

2. **OpenCV Not Found**
   - Verify OpenCV installation
   - Set `OPENCV_DIR` environment variable if needed

3. **Build Failures**
   - Clean build: `flutter clean`
   - Update dependencies: `flutter pub upgrade`
   - Check platform-specific requirements

4. **Performance Issues**
   - Reduce camera resolution
   - Implement frame skipping
   - Use mock camera for development

### Debug Mode

Enable debug logging in `camera_service.dart`:
```dart
// Set to false for production
static const bool DEBUG_LOGS = true;
```

## Monitoring and Analytics

### Integration with Analytics Services

The application supports integration with:
- Firebase Analytics
- Custom analytics endpoints
- Local performance monitoring

### Log Collection

Configure logging levels in `app.dart`:
```dart
// Production logging level
Logger.level = Level.WARNING;
```

## Security Considerations

1. **Data Encryption**
   - User data is encrypted at rest
   - Secure storage for authentication tokens

2. **Camera Access**
   - Permission-based camera access
   - No image data stored without consent

3. **Network Security**
   - HTTPS for all API calls
   - Certificate pinning (optional)

## Maintenance

### Updating Dependencies

Regularly update dependencies:
```bash
flutter pub outdated
flutter pub upgrade
```

### Platform Updates

Monitor platform-specific requirements:
- iOS minimum version
- Android API level
- Desktop platform requirements

### Backup and Recovery

Implement data backup strategies:
- Cloud synchronization
- Local backup exports
- Migration tools between storage types

## Support

For technical support:
1. Check the project documentation
2. Review troubleshooting section
3. Create issues on the project repository
4. Contact development team

## License

This project is licensed under the MIT License. See LICENSE file for details.
