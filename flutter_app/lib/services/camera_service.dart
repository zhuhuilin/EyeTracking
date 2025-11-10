import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';

import '../models/app_state.dart';

class CameraService {
  static const MethodChannel _channel = MethodChannel(
    'eyeball_tracking/camera',
  );
  static const EventChannel _trackingChannel = EventChannel(
    'eyeball_tracking/tracking',
  );

  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _isTracking = false;
  StreamSubscription<TrackingResult>? _trackingSubscription;

  // Camera configuration
  static const ResolutionPreset _resolution = ResolutionPreset.medium;
  static const int _frameRate = 30;

  // Tracking results stream
  final StreamController<TrackingResult> _trackingController =
      StreamController<TrackingResult>.broadcast();

  Stream<TrackingResult> get trackingResults => _trackingController.stream;

  Future<void> initialize() async {
    try {
      // Get available cameras
      final cameras = await availableCameras();

      // Use the front camera for eye tracking
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        _resolution,
        imageFormatGroup: ImageFormatGroup.yuv420,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      _isInitialized = true;

      // Initialize native tracking engine
      await _channel.invokeMethod('initializeTrackingEngine');

      print('Camera service initialized successfully');
    } catch (e) {
      print('Failed to initialize camera service: $e');
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

  void _processCameraImage(CameraImage image) {
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

  Uint8List _convertImageToNativeFormat(CameraImage image) {
    // Convert YUV420 to RGB for processing
    // This is a simplified conversion - in production, use proper YUV to RGB conversion
    if (image.format.group == ImageFormatGroup.yuv420) {
      return _yuv420ToRgb(image);
    } else if (image.format.group == ImageFormatGroup.bgra8888) {
      return image.planes[0].bytes;
    } else {
      // Fallback: use first plane
      return image.planes[0].bytes;
    }
  }

  Uint8List _yuv420ToRgb(CameraImage image) {
    // Simplified YUV to RGB conversion
    // Note: This is a placeholder - use proper conversion in production
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    // Create RGB buffer (3 bytes per pixel)
    final rgbData = Uint8List(image.width * image.height * 3);

    // Simple conversion (this would be replaced with proper YUV to RGB algorithm)
    for (int i = 0; i < yPlane.bytes.length; i++) {
      final y = yPlane.bytes[i] & 0xFF;
      // Use average UV for simplicity
      final u = uPlane.bytes[i ~/ 4] & 0xFF;
      final v = vPlane.bytes[i ~/ 4] & 0xFF;

      // Convert YUV to RGB (simplified)
      final r = y.clamp(0, 255);
      final g = y.clamp(0, 255);
      final b = y.clamp(0, 255);

      final pixelIndex = i * 3;
      rgbData[pixelIndex] = r;
      rgbData[pixelIndex + 1] = g;
      rgbData[pixelIndex + 2] = b;
    }

    return rgbData;
  }

  String _getImageFormat(ImageFormat format) {
    switch (format.group) {
      case ImageFormatGroup.yuv420:
        return 'yuv420';
      case ImageFormatGroup.bgra8888:
        return 'bgra8888';
      case ImageFormatGroup.jpeg:
        return 'jpeg';
      case ImageFormatGroup.nv21:
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

  CameraController? get cameraController => _cameraController;
  bool get isInitialized => _isInitialized;
  bool get isTracking => _isTracking;

  Future<void> dispose() async {
    await stopTracking();
    await _trackingSubscription?.cancel();
    await _cameraController?.dispose();
    await _trackingController.close();
    _isInitialized = false;
    _isTracking = false;
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
  Future<void> initialize() async {
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
  }
}
