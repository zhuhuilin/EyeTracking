import 'dart:async';
import 'dart:typed_data';
import 'dart:io' show Platform;
import 'dart:ui' show Rect;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart' as cam;
import 'package:camera_macos/camera_macos.dart' as cam_macos;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_state.dart';
import '../models/model_info.dart';
import '../models/calibration_data.dart';
import 'model_registry.dart';

enum FaceDetectionBackend {
  auto,
  yolo,
  yunet,
  haar,
}

extension FaceDetectionBackendX on FaceDetectionBackend {
  String get label {
    switch (this) {
      case FaceDetectionBackend.yolo:
        return 'YOLO (High Accuracy)';
      case FaceDetectionBackend.yunet:
        return 'YuNet (Balanced)';
      case FaceDetectionBackend.haar:
        return 'Haar Cascade (Legacy)';
      case FaceDetectionBackend.auto:
      default:
        return 'Auto (Smart Fallback)';
    }
  }

  String get channelValue {
    switch (this) {
      case FaceDetectionBackend.yolo:
        return 'yolo';
      case FaceDetectionBackend.yunet:
        return 'yunet';
      case FaceDetectionBackend.haar:
        return 'haar';
      case FaceDetectionBackend.auto:
      default:
        return 'auto';
    }
  }

  static FaceDetectionBackend fromChannelValue(String value) {
    final normalized = value.toLowerCase();
    switch (normalized) {
      case 'yolo':
      case 'yolov5':
      case 'yolov8':
        return FaceDetectionBackend.yolo;
      case 'yunet':
        return FaceDetectionBackend.yunet;
      case 'haar':
      case 'haarcascade':
        return FaceDetectionBackend.haar;
      case 'auto':
      default:
        return FaceDetectionBackend.auto;
    }
  }
}

class CameraService extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel(
    'eyeball_tracking/camera',
  );
  static const EventChannel _trackingChannel = EventChannel(
    'eyeball_tracking/tracking',
  );

  cam.CameraController? _cameraController;
  cam_macos.CameraMacOSController? _macCameraController;
  bool _isInitialized = false;
  bool _isTracking = false;
  bool _macImageStreamActive = false;
  StreamSubscription<TrackingResult>? _trackingSubscription;
  List<cam.CameraDescription> _availableCameras = [];
  cam.CameraDescription? _selectedCamera;
  final Map<String, String> _cameraDeviceIds =
      {}; // Map camera name to device ID
  TrackingResult? _latestTrackingResult;
  FaceDetectionBackend _faceDetectionBackend = FaceDetectionBackend.auto;
  String? _selectedModelId; // Currently selected model ID
  bool _nativeEngineReady = false;

  // Camera configuration
  static const cam.ResolutionPreset _resolution = cam.ResolutionPreset.medium;
  static const int _frameRate = 30;

  // Tracking results stream
  final StreamController<TrackingResult> _trackingController =
      StreamController<TrackingResult>.broadcast();

  Stream<TrackingResult> get trackingResults => _trackingController.stream;
  TrackingResult? get latestTrackingResult => _latestTrackingResult;
  List<cam.CameraDescription> get availableCameras => _availableCameras;
  cam.CameraDescription? get selectedCamera => _selectedCamera;
  String? get selectedCameraDeviceId =>
      _selectedCamera != null ? _cameraDeviceIds[_selectedCamera!.name] : null;
  FaceDetectionBackend get faceDetectionBackend => _faceDetectionBackend;
  String? get selectedModelId => _selectedModelId;
  bool get _usingMacOSCamera => !kIsWeb && Platform.isMacOS;
  bool get hasMacCameraController => _macCameraController != null;

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
          print(
              'camera_macos returned 0 devices, trying custom camera helper...');
          try {
            const MethodChannel helperChannel =
                MethodChannel('eyeball_tracking/camera_helper');
            final result = await helperChannel.invokeMethod('listCameras');

            if (result is Map && result['devices'] is List) {
              final devices = result['devices'] as List;
              print('Custom helper found ${devices.length} devices');

              _availableCameras = devices.map((device) {
                final deviceMap = device as Map;
                return cam.CameraDescription(
                  name:
                      deviceMap['localizedName'] as String? ?? 'Unknown Camera',
                  lensDirection: cam.CameraLensDirection.external,
                  sensorOrientation: 0,
                );
              }).toList();

              print(
                  'Successfully detected ${_availableCameras.length} cameras via custom helper');
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

      if (_usingMacOSCamera) {
        _cameraController = null;
        _isInitialized = true;
        notifyListeners();
        if (!_nativeEngineReady) {
          await _channel.invokeMethod('initializeTrackingEngine');
          _nativeEngineReady = true;
          await _applyFaceDetectionBackend();
          await _loadSelectedModel();
        }
        return;
      }

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
      notifyListeners();

      if (!_nativeEngineReady) {
        await _channel.invokeMethod('initializeTrackingEngine');
        _nativeEngineReady = true;
        await _applyFaceDetectionBackend();
        await _loadSelectedModel();
      }

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
    print('[CameraService] startTracking() called');
    print('[CameraService] - isInitialized: $_isInitialized');
    print('[CameraService] - isTracking: $_isTracking');
    print('[CameraService] - usingMacOSCamera: $_usingMacOSCamera');
    print(
        '[CameraService] - macCameraController: ${_macCameraController != null}');

    if (!_isInitialized) {
      print('[CameraService] Not initialized, initializing first...');
      await initialize();
    }
    if (_usingMacOSCamera && _macCameraController == null) {
      print(
          '[CameraService] startTracking waiting: macOS controller not attached');
      return;
    }
    if (_isTracking) {
      print('[CameraService] Already tracking, skipping');
      return;
    }

    try {
      if (_usingMacOSCamera) {
        print('[CameraService] Starting macOS tracking...');
        await _startMacTracking();
      } else {
        print('[CameraService] Starting standard camera tracking...');
        await _cameraController!.startImageStream(_processCameraImage);
      }

      print('[CameraService] Calling native startTracking...');
      await _channel.invokeMethod('startTracking');

      print('[CameraService] Setting up tracking event stream...');
      _trackingSubscription = _trackingChannel
          .receiveBroadcastStream()
          .map((data) => _parseTrackingResult(data))
          .listen((result) {
        _trackingController.add(result);
        _latestTrackingResult = result;
        notifyListeners();
      });

      _isTracking = true;
      print('[CameraService] Tracking started successfully');
    } catch (e, stack) {
      print('[CameraService] Failed to start tracking: $e');
      print(stack);
      rethrow;
    }
  }

  Future<void> stopTracking() async {
    print('[CameraService] stopTracking() called');
    if (!_isTracking) {
      print('[CameraService] Not tracking, skipping');
      return;
    }

    try {
      // Stop camera stream
      if (_usingMacOSCamera) {
        print('[CameraService] Stopping macOS image stream...');
        await _stopMacTracking();
      } else {
        print('[CameraService] Stopping standard camera stream...');
        await _cameraController!.stopImageStream();
      }

      // Stop native tracking
      print('[CameraService] Calling native stopTracking...');
      await _channel.invokeMethod('stopTracking');

      // Cancel tracking subscription
      print('[CameraService] Canceling tracking subscription...');
      await _trackingSubscription?.cancel();
      _trackingSubscription = null;

      _isTracking = false;
      _latestTrackingResult = null;
      notifyListeners();
      print('[CameraService] Tracking stopped successfully');
    } catch (e, stack) {
      print('[CameraService] Failed to stop tracking: $e');
      print(stack);
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

  Future<void> _startMacTracking() async {
    if (_macCameraController == null) {
      throw StateError('Mac camera controller not attached');
    }
    if (_macImageStreamActive) return;

    print('[CameraService] Starting macOS image stream...');
    await _macCameraController!.startImageStream(
      _handleMacImageFrame,
      onError: (error) {
        print('[CameraService] Mac image stream error: $error');
      },
    );
    _macImageStreamActive = true;
    print('[CameraService] macOS image stream started successfully');
  }

  Future<void> _stopMacTracking() async {
    if (!_macImageStreamActive) return;
    try {
      await _macCameraController?.stopImageStream();
    } finally {
      _macImageStreamActive = false;
    }
  }

  int _macFrameCount = 0;
  bool _macLoggedFirstFrame = false;
  bool _isProcessingFrame = false;

  void _handleMacImageFrame(cam_macos.CameraImageData? data) {
    if (!_macLoggedFirstFrame) {
      print(
          '[CameraService] First frame callback received! data is ${data == null ? "null" : "valid"}');
      if (data != null) {
        print(
            '[CameraService] Frame size: ${data.width}x${data.height}, bytesPerRow: ${data.bytesPerRow}, bytes: ${data.bytes.length}');
      }
      _macLoggedFirstFrame = true;
    }

    if (!_isTracking) {
      print('[CameraService] Frame received but tracking is not active');
      return;
    }

    if (data == null) {
      print('[CameraService] Received null frame data');
      return;
    }

    // Skip processing if we're already processing a frame
    if (_isProcessingFrame) {
      return;
    }

    _isProcessingFrame = true;

    try {
      final rgbBytes = _convertBgraToRgb(data);
      _channel.invokeMethod('processFrame', {
        'data': rgbBytes,
        'width': data.width,
        'height': data.height,
        'format': 'rgb',  // Changed from 'bgra8888' to 'rgb' since we're converting
      }).whenComplete(() {
        _isProcessingFrame = false;
      });

      _macFrameCount++;
      if (_macFrameCount % 30 == 0) {
        print('[CameraService] Processed $_macFrameCount frames');
      }
    } catch (e, stack) {
      print('[CameraService] Error processing mac image: $e');
      print(stack);
      _isProcessingFrame = false;
    }
  }

  Uint8List _convertBgraToRgb(cam_macos.CameraImageData data) {
    final width = data.width;
    final height = data.height;
    final bytesPerRow = data.bytesPerRow;
    final source = data.bytes;

    final rgb = Uint8List(width * height * 3);
    int dstIndex = 0;

    for (int y = 0; y < height; y++) {
      final rowStart = y * bytesPerRow;
      for (int x = 0; x < width; x++) {
        final pixelOffset = rowStart + x * 4;
        final b = source[pixelOffset];
        final g = source[pixelOffset + 1];
        final r = source[pixelOffset + 2];
        rgb[dstIndex++] = r;
        rgb[dstIndex++] = g;
        rgb[dstIndex++] = b;
      }
    }
    return rgb;
  }

  Future<void> attachMacCameraController(
    cam_macos.CameraMacOSController controller,
  ) async {
    _macCameraController = controller;
    if (!_isInitialized) {
      _isInitialized = true;
      notifyListeners();
    }
    if (!_nativeEngineReady) {
      await _channel.invokeMethod('initializeTrackingEngine');
      _nativeEngineReady = true;
      await _applyFaceDetectionBackend();
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
      Rect? faceRect;
      bool faceDetected = false;

      final rectData = data['faceRect'];
      if (rectData is Map) {
        faceDetected = rectData['detected'] == true;
        final double? x = (rectData['x'] as num?)?.toDouble();
        final double? y = (rectData['y'] as num?)?.toDouble();
        final double? width = (rectData['width'] as num?)?.toDouble();
        final double? height = (rectData['height'] as num?)?.toDouble();
        if (faceDetected &&
            x != null &&
            y != null &&
            width != null &&
            height != null) {
          faceRect = Rect.fromLTWH(x, y, width, height);
        }
      }

      // Parse extended tracking data
      List<Point> faceLandmarks = [];
      if (data['faceLandmarks'] is List) {
        faceLandmarks = (data['faceLandmarks'] as List).map((p) {
          final point = p as Map;
          return Point(
            (point['x'] as num).toDouble(),
            (point['y'] as num).toDouble(),
          );
        }).toList();
      }

      // Extract eye landmarks from face landmarks (if we have enough)
      List<Point> leftEyeLandmarks = [];
      List<Point> rightEyeLandmarks = [];
      if (faceLandmarks.length >= 12) {
        // Assuming eyes are in landmarks 4-9 (left eye) and 10-15 (right eye)
        // This matches the approximate positions from detectFaceLandmarks
        leftEyeLandmarks = faceLandmarks.length > 5 ? faceLandmarks.sublist(4, 8) : [];
        rightEyeLandmarks = faceLandmarks.length > 9 ? faceLandmarks.sublist(6, 10) : [];
      }

      Vector3 headPose = const Vector3(0, 0, 0);
      if (data['headPose'] is Map) {
        final pose = data['headPose'] as Map;
        headPose = Vector3(
          (pose['x'] as num?)?.toDouble() ?? 0.0,
          (pose['y'] as num?)?.toDouble() ?? 0.0,
          (pose['z'] as num?)?.toDouble() ?? 0.0,
        );
      }

      Vector3 gazeVector = const Vector3(0, 0, 1);
      if (data['gazeVector'] is Map) {
        final gaze = data['gazeVector'] as Map;
        gazeVector = Vector3(
          (gaze['x'] as num?)?.toDouble() ?? 0.0,
          (gaze['y'] as num?)?.toDouble() ?? 0.0,
          (gaze['z'] as num?)?.toDouble() ?? 1.0,
        );
      }

      final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.0;

      return ExtendedTrackingResult(
        faceDistance: (data['faceDistance'] as num?)?.toDouble() ?? 0.0,
        gazeAngleX: (data['gazeAngleX'] as num?)?.toDouble() ?? 0.0,
        gazeAngleY: (data['gazeAngleY'] as num?)?.toDouble() ?? 0.0,
        eyesFocused: data['eyesFocused'] ?? false,
        headMoving: data['headMoving'] ?? false,
        shouldersMoving: data['shouldersMoving'] ?? false,
        faceDetected: faceRect != null || (data['faceDetected'] ?? false),
        faceRect: faceRect,
        faceLandmarks: faceLandmarks,
        leftEyeLandmarks: leftEyeLandmarks,
        rightEyeLandmarks: rightEyeLandmarks,
        headPose: headPose,
        gazeVector: gazeVector,
        confidence: confidence,
      );
    }
    return ExtendedTrackingResult(
      faceDistance: 0.0,
      gazeAngleX: 0.0,
      gazeAngleY: 0.0,
      eyesFocused: false,
      headMoving: false,
      shouldersMoving: false,
      faceDetected: false,
      faceRect: null,
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

  Future<void> setFaceDetectionBackend(FaceDetectionBackend backend) async {
    _faceDetectionBackend = backend;
    await _applyFaceDetectionBackend();
    notifyListeners();
  }

  Future<void> _applyFaceDetectionBackend() async {
    if (!_nativeEngineReady) {
      return;
    }

    try {
      await _channel.invokeMethod('setFaceDetectionBackend', {
        'backend': _faceDetectionBackend.channelValue,
      });
      print('Applied face detector backend: ${_faceDetectionBackend.label}');
    } catch (e) {
      print('Failed to apply face detection backend: $e');
    }
  }

  /// Set the detection model by model ID
  /// Returns true if model was successfully loaded, false otherwise
  Future<bool> setModel(String modelId) async {
    try {
      final ModelRegistry registry = ModelRegistry.instance;
      final ModelInfo? model = registry.getModelById(modelId);

      if (model == null) {
        print('Model not found: $modelId');
        return false;
      }

      if (!model.isAvailable) {
        print('Model not available (not downloaded): ${model.fullDisplayName}');
        return false;
      }

      // Save selected model ID to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_model_id', modelId);

      _selectedModelId = modelId;

      // Apply model to native layer if engine is ready
      if (_nativeEngineReady) {
        await _applyModel(model);
      }

      notifyListeners();
      print('Selected model: ${model.fullDisplayName}');
      return true;
    } catch (e) {
      print('Failed to set model: $e');
      return false;
    }
  }

  /// Apply the selected model to the native tracking engine
  Future<void> _applyModel(ModelInfo model) async {
    if (!_nativeEngineReady) {
      return;
    }

    try {
      await _channel.invokeMethod('setModel', {
        'modelId': model.id,
        'modelPath': model.filePath,
        'modelType': model.type.name,
        'modelVariant': model.variant.name,
        'modelFormat': model.format.name,
      });
      print('Applied model to native layer: ${model.fullDisplayName}');
    } catch (e) {
      print('Failed to apply model to native layer: $e');
      rethrow;
    }
  }

  /// Load the selected model from preferences
  Future<void> _loadSelectedModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedModelId = prefs.getString('selected_model_id');

      if (savedModelId != null) {
        final registry = ModelRegistry.instance;
        final model = registry.getModelById(savedModelId);

        if (model != null && model.isAvailable) {
          _selectedModelId = savedModelId;
          if (_nativeEngineReady) {
            await _applyModel(model);
          }
          print('Loaded saved model: ${model.fullDisplayName}');
        } else {
          print('Saved model not available, will use default');
        }
      }
    } catch (e) {
      print('Failed to load selected model: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await stopTracking();
    await _trackingSubscription?.cancel();
    await _cameraController?.dispose();
    try {
      await _macCameraController?.destroy();
    } catch (_) {}
    await _trackingController.close();
    _isInitialized = false;
    _isTracking = false;
    _nativeEngineReady = false;
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
    _nativeEngineReady = true;
    await _applyFaceDetectionBackend();
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
        faceDetected: true,
        faceRect: const Rect.fromLTWH(0.35, 0.25, 0.3, 0.3),
      );

      _trackingController.add(mockResult);
      _latestTrackingResult = mockResult;
      notifyListeners();
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
