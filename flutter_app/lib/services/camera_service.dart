import 'dart:async';
import 'dart:typed_data';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart' as cam;
import 'package:camera_macos/camera_macos.dart' as cam_macos;

import '../models/app_state.dart';

class CameraService extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel(
    'eyeball_tracking/camera',
  );
  static const EventChannel _trackingChannel = EventChannel(
    'eyeball_tracking/tracking',
  );

  cam.CameraController? _cameraController;
  bool _isInitialized = false;
  bool _isTracking = false;
  StreamSubscription<TrackingResult>? _trackingSubscription;
  List<cam.CameraDescription> _availableCameras = [];
  cam.CameraDescription? _selectedCamera;
  final Map<String, String> _cameraDeviceIds = {}; // Map camera name to device ID

  // Camera configuration
  static const cam.ResolutionPreset _resolution = cam.ResolutionPreset.medium;
  static const int _frameRate = 30;

  // Tracking results stream
  final StreamController<TrackingResult> _trackingController =
      StreamController<TrackingResult>.broadcast();

  Stream<TrackingResult> get trackingResults => _trackingController.stream;
  List<cam.CameraDescription> get availableCameras => _availableCameras;
  cam.CameraDescription? get selectedCamera => _selectedCamera;
  String? get selectedCameraDeviceId =>
      _selectedCamera != null ? _cameraDeviceIds[_selectedCamera!.name] : null;

  Future<List<cam.CameraDescription>> detectCameras() async {
    try {
      // Use camera_macos on macOS, regular camera plugin on other platforms
      if (!kIsWeb && Platform.isMacOS) {
        print('Using camera_macos to detect cameras...');
        final macCameras = await cam_macos.CameraMacOS.instance.listDevices(
          deviceType: cam_macos.CameraMacOSDeviceType.video,
        );
        print('camera_macos returned ${macCameras.length} devices');

        // If camera_macos returns 0 devices, try our custom helper
        if (macCameras.isEmpty) {
          print('camera_macos returned 0 devices, trying custom camera helper...');
          try {
            const MethodChannel helperChannel = MethodChannel('eyeball_tracking/camera_helper');
            final result = await helperChannel.invokeMethod('listCameras');

            if (result is Map && result['devices'] is List) {
              final devices = result['devices'] as List;
              print('Custom helper found ${devices.length} devices');

              _availableCameras = devices.map((device) {
                final deviceMap = device as Map;
                return cam.CameraDescription(
                  name: deviceMap['localizedName'] as String? ?? 'Unknown Camera',
                  lensDirection: cam.CameraLensDirection.external,
                  sensorOrientation: 0,
                );
              }).toList();

              print('Successfully detected ${_availableCameras.length} cameras via custom helper');
              for (var camera in _availableCameras) {
                print(' - ${camera.name}');
              }
              return _availableCameras;
            }
          } catch (helperError) {
            print('Custom helper also failed: $helperError');
          }
        } else {
          // Clear previous device ID mappings
          _cameraDeviceIds.clear();

          for (var macCam in macCameras) {
            print('  Device: ${macCam.localizedName} (${macCam.deviceId})');
          }

          _availableCameras = macCameras.map((macCam) {
            final cameraName = macCam.localizedName ?? macCam.deviceId;
            // Store the mapping from camera name to device ID
            _cameraDeviceIds[cameraName] = macCam.deviceId;

            return cam.CameraDescription(
              name: cameraName,
              lensDirection: cam.CameraLensDirection.external,
              sensorOrientation: 0,
            );
          }).toList();
        }
      } else {
        _availableCameras = await cam.availableCameras();
      }

      print('Detected ${_availableCameras.length} cameras:');
      for (var camera in _availableCameras) {
        print(' - ${camera.name} (${camera.lensDirection})');
      }
      return _availableCameras;
    } catch (e, stackTrace) {
      print('Failed to detect cameras: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<void> initialize({cam.CameraDescription? camera}) async {
    try {
      // If no cameras detected yet, detect them first
      if (_availableCameras.isEmpty) {
        await detectCameras();
      }

      // Use provided camera or default to front camera
      _selectedCamera = camera ??
          _availableCameras.firstWhere(
            (camera) => camera.lensDirection == cam.CameraLensDirection.front,
            orElse: () => _availableCameras.first,
          );

      if (_cameraController != null) {
        await _cameraController!.dispose();
      }

      _cameraController = cam.CameraController(
        _selectedCamera!,
        _resolution,
        imageFormatGroup: cam.ImageFormatGroup.yuv420,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      _isInitialized = true;

      // Initialize native tracking engine
      await _channel.invokeMethod('initializeTrackingEngine');

      print('Camera service initialized with: ${_selectedCamera!.name}');
    } catch (e) {
      print('Failed to initialize camera service: $e');
      rethrow;
    }
  }

  Future<void> switchCamera(cam.CameraDescription camera) async {
    if (_selectedCamera?.name == camera.name) return;

    try {
      _selectedCamera = camera;
      notifyListeners();

      if (!_isInitialized) {
        print('Camera not initialized yet, just updating selection');
        return;
      }

      final wasTracking = _isTracking;
      if (_isTracking) {
        await stopTracking();
      }

      await initialize(camera: camera);

      if (wasTracking) {
        await startTracking();
      }

      print('Switched to camera: ${camera.name}');
    } catch (e) {
      print('Failed to switch camera: $e');
      rethrow;
    }
  }

  Future<void> startTracking() async {
    if (!_isInitialized || _isTracking) return;

    try {
      // Start camera preview
      await _cameraController!.startImageStream(_processCameraImage);

      // Start native tracking
      await _channel.invokeMethod('startTracking');

      // Listen for tracking results
      _trackingSubscription = _trackingChannel
          .receiveBroadcastStream()
          .map((data) => _parseTrackingResult(data))
          .listen(_trackingController.add);

      _isTracking = true;
      print('Tracking started');
    } catch (e) {
      print('Failed to start tracking: $e');
      rethrow;
    }
  }

  Future<void> stopTracking() async {
    if (!_isTracking) return;

    try {
      // Stop camera stream
      await _cameraController!.stopImageStream();

      // Stop native tracking
      await _channel.invokeMethod('stopTracking');

      // Cancel tracking subscription
      await _trackingSubscription?.cancel();
      _trackingSubscription = null;

      _isTracking = false;
      print('Tracking stopped');
    } catch (e) {
      print('Failed to stop tracking: $e');
      rethrow;
    }
  }

  void _processCameraImage(cam.CameraImage image) {
    if (!_isTracking) return;

    try {
      // Convert camera image to format suitable for native processing
      final imageData = _convertImageToNativeFormat(image);

      // Send frame to native code for processing
      _channel.invokeMethod('processFrame', {
        'data': imageData,
        'width': image.width,
        'height': image.height,
        'format': _getImageFormat(image.format),
      });
    } catch (e) {
      print('Error processing camera image: $e');
    }
  }

  Uint8List _convertImageToNativeFormat(cam.CameraImage image) {
    // Convert YUV420 to RGB for processing
    // This is a simplified conversion - in production, use proper YUV to RGB conversion
    if (image.format.group == cam.ImageFormatGroup.yuv420) {
      return _yuv420ToRgb(image);
    } else if (image.format.group == cam.ImageFormatGroup.bgra8888) {
      return image.planes[0].bytes;
    } else {
      // Fallback: use first plane
      return image.planes[0].bytes;
    }
  }

  Uint8List _yuv420ToRgb(cam.CameraImage image) {
    // Proper YUV420 to RGB conversion
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final width = image.width;
    final height = image.height;

    // Create RGB buffer (3 bytes per pixel)
    final rgbData = Uint8List(width * height * 3);

    // YUV420 to RGB conversion formulas
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixelIndex = y * width + x;
        final uvIndex = (y ~/ 2) * (width ~/ 2) + (x ~/ 2);

        final Y = yPlane.bytes[pixelIndex] & 0xFF;
        final U = uPlane.bytes[uvIndex] & 0xFF;
        final V = vPlane.bytes[uvIndex] & 0xFF;

        // Convert YUV to RGB using standard formulas
        final r = (Y + 1.402 * (V - 128)).round().clamp(0, 255);
        final g = (Y - 0.344136 * (U - 128) - 0.714136 * (V - 128))
            .round()
            .clamp(0, 255);
        final b = (Y + 1.772 * (U - 128)).round().clamp(0, 255);

        final rgbIndex = pixelIndex * 3;
        rgbData[rgbIndex] = r;
        rgbData[rgbIndex + 1] = g;
        rgbData[rgbIndex + 2] = b;
      }
    }

    return rgbData;
  }

  String _getImageFormat(cam.ImageFormat format) {
    switch (format.group) {
      case cam.ImageFormatGroup.yuv420:
        return 'yuv420';
      case cam.ImageFormatGroup.bgra8888:
        return 'bgra8888';
      case cam.ImageFormatGroup.jpeg:
        return 'jpeg';
      case cam.ImageFormatGroup.nv21:
        return 'nv21';
      default:
        return 'unknown';
    }
  }

  TrackingResult _parseTrackingResult(dynamic data) {
    if (data is Map) {
      return TrackingResult(
        faceDistance: (data['faceDistance'] as num?)?.toDouble() ?? 0.0,
        gazeAngleX: (data['gazeAngleX'] as num?)?.toDouble() ?? 0.0,
        gazeAngleY: (data['gazeAngleY'] as num?)?.toDouble() ?? 0.0,
        eyesFocused: data['eyesFocused'] ?? false,
        headMoving: data['headMoving'] ?? false,
        shouldersMoving: data['shouldersMoving'] ?? false,
      );
    }
    return TrackingResult(
      faceDistance: 0.0,
      gazeAngleX: 0.0,
      gazeAngleY: 0.0,
      eyesFocused: false,
      headMoving: false,
      shouldersMoving: false,
    );
  }

  Future<void> setCameraParameters(
    double focalLength,
    double principalX,
    double principalY,
  ) async {
    await _channel.invokeMethod('setCameraParameters', {
      'focalLength': focalLength,
      'principalX': principalX,
      'principalY': principalY,
    });
  }

  Future<void> startCalibration() async {
    await _channel.invokeMethod('startCalibration');
  }

  Future<void> addCalibrationPoint(double x, double y) async {
    await _channel.invokeMethod('addCalibrationPoint', {'x': x, 'y': y});
  }

  Future<void> finishCalibration() async {
    await _channel.invokeMethod('finishCalibration');
  }

  cam.CameraController? get cameraController => _cameraController;
  bool get isInitialized => _isInitialized;
  bool get isTracking => _isTracking;

  @override
  Future<void> dispose() async {
    await stopTracking();
    await _trackingSubscription?.cancel();
    await _cameraController?.dispose();
    await _trackingController.close();
    _isInitialized = false;
    _isTracking = false;
    super.dispose();
  }
}

// Platform channel interface for native implementations
abstract class NativeCameraInterface {
  Future<void> initializeTrackingEngine();
  Future<void> startTracking();
  Future<void> stopTracking();
  Future<void> processFrame(Map<String, dynamic> frameData);
  Future<void> setCameraParameters(Map<String, dynamic> parameters);
  Future<void> startCalibration();
  Future<void> addCalibrationPoint(Map<String, dynamic> point);
  Future<void> finishCalibration();
}

// Mock implementation for development
class MockCameraService extends CameraService {
  @override
  Future<void> initialize({cam.CameraDescription? camera}) async {
    // Simulate camera initialization
    await Future.delayed(const Duration(seconds: 1));
    _isInitialized = true;
    print('Mock camera service initialized');
  }

  @override
  Future<void> startTracking() async {
    if (!_isInitialized || _isTracking) return;

    _isTracking = true;

    // Simulate tracking results
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isTracking) {
        timer.cancel();
        return;
      }

      // Generate mock tracking data
      final mockResult = TrackingResult(
        faceDistance: 50.0 + (DateTime.now().millisecond % 20).toDouble(),
        gazeAngleX: (DateTime.now().millisecond % 100 - 50) / 100.0,
        gazeAngleY: (DateTime.now().millisecond % 100 - 50) / 100.0,
        eyesFocused: DateTime.now().millisecond % 200 < 100,
        headMoving: DateTime.now().millisecond % 500 < 50,
        shouldersMoving: DateTime.now().millisecond % 1000 < 20,
      );

      _trackingController.add(mockResult);
    });

    print('Mock tracking started');
  }

  @override
  Future<void> stopTracking() async {
    _isTracking = false;
    print('Mock tracking stopped');
  }

  @override
  Future<void> dispose() async {
    _isTracking = false;
    await _trackingController.close();
    super.dispose();
  }
}
