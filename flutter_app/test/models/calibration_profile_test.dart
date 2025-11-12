import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:eyeball_tracking/models/calibration_profile.dart';
import 'package:eyeball_tracking/models/calibration_data.dart';

void main() {
  group('CalibrationProfile', () {
    late CalibrationSession testSession;
    late List<CalibrationDataPoint> testDataPoints;

    setUp(() {
      // Create test calibration data points
      testDataPoints = [
        CalibrationDataPoint(
          targetPosition: const Offset(100, 100),
          tracking: ExtendedTrackingResult(
            faceDistance: 50.0,
            gazeAngleX: 0.1,
            gazeAngleY: 0.05,
            eyesFocused: true,
            headMoving: false,
            shouldersMoving: false,
            faceDetected: true,
            faceRect: const Rect.fromLTWH(0.2, 0.2, 0.3, 0.4),
            faceLandmarks: [],
            leftEyeLandmarks: [],
            rightEyeLandmarks: [],
            headPose: const Vector3(5.0, -2.0, 1.0),
            gazeVector: const Vector3(0.02, -0.03, 0.99),
            confidence: 0.85,
          ),
          timestamp: DateTime.now(),
          dwellTime: const Duration(seconds: 3),
        ),
        CalibrationDataPoint(
          targetPosition: const Offset(300, 100),
          tracking: ExtendedTrackingResult(
            faceDistance: 52.0,
            gazeAngleX: 0.12,
            gazeAngleY: 0.06,
            eyesFocused: true,
            headMoving: false,
            shouldersMoving: false,
            faceDetected: true,
            faceRect: const Rect.fromLTWH(0.2, 0.2, 0.3, 0.4),
            faceLandmarks: [],
            leftEyeLandmarks: [],
            rightEyeLandmarks: [],
            headPose: const Vector3(4.8, -2.2, 0.9),
            gazeVector: const Vector3(0.03, -0.02, 0.99),
            confidence: 0.88,
          ),
          timestamp: DateTime.now(),
          dwellTime: const Duration(seconds: 3),
        ),
        CalibrationDataPoint(
          targetPosition: const Offset(200, 200),
          tracking: ExtendedTrackingResult(
            faceDistance: 51.0,
            gazeAngleX: 0.11,
            gazeAngleY: 0.055,
            eyesFocused: true,
            headMoving: false,
            shouldersMoving: false,
            faceDetected: true,
            faceRect: const Rect.fromLTWH(0.2, 0.2, 0.3, 0.4),
            faceLandmarks: [],
            leftEyeLandmarks: [],
            rightEyeLandmarks: [],
            headPose: const Vector3(5.1, -1.9, 1.1),
            gazeVector: const Vector3(0.025, -0.025, 0.99),
            confidence: 0.82,
          ),
          timestamp: DateTime.now(),
          dwellTime: const Duration(seconds: 3),
        ),
      ];

      testSession = CalibrationSession(
        id: 'test_session_1',
        userId: 'test_user',
        createdAt: DateTime.now(),
        modelId: 'yolo11_medium',
        cameraId: 'camera_1',
        dataPoints: testDataPoints,
      );
    });

    test('should create profile from session', () {
      final profile = CalibrationProfile.fromSession(testSession);

      expect(profile.id, equals(testSession.id));
      expect(profile.userId, equals(testSession.userId));
      expect(profile.modelId, equals(testSession.modelId));
      expect(profile.cameraId, equals(testSession.cameraId));
      expect(profile.dataPoints.length, equals(3));
    });

    test('should calculate quality score', () {
      final profile = CalibrationProfile.fromSession(testSession);

      expect(profile.qualityScore, greaterThan(0));
      expect(profile.qualityScore, lessThanOrEqualTo(100));
    });

    test('should calculate average confidence', () {
      final profile = CalibrationProfile.fromSession(testSession);

      // Average of 0.85, 0.88, 0.82 = 0.85
      expect(profile.averageConfidence, closeTo(0.85, 0.01));
    });

    test('should calculate head pose consistency', () {
      final profile = CalibrationProfile.fromSession(testSession);

      // Should be high since head pose is consistent
      expect(profile.headPoseConsistency, greaterThan(0.8));
    });

    test('should calculate completeness score', () {
      final profile = CalibrationProfile.fromSession(testSession);

      // All 3 points have face detected with confidence > 0.5
      expect(profile.completenessScore, equals(1.0));
    });

    test('should calculate head pose baseline', () {
      final profile = CalibrationProfile.fromSession(testSession);

      // Average pitch: (5.0 + 4.8 + 5.1) / 3 = 4.97
      expect(profile.headPoseBaseline.x, closeTo(4.97, 0.1));
      // Average yaw: (-2.0 + -2.2 + -1.9) / 3 = -2.03
      expect(profile.headPoseBaseline.y, closeTo(-2.03, 0.1));
      // Average roll: (1.0 + 0.9 + 1.1) / 3 = 1.0
      expect(profile.headPoseBaseline.z, closeTo(1.0, 0.1));
    });

    test('should calculate gaze offsets', () {
      final profile = CalibrationProfile.fromSession(testSession);

      expect(profile.gazeOffsets, contains('offsetX'));
      expect(profile.gazeOffsets, contains('offsetY'));
      expect(profile.gazeOffsets['offsetX'], isNotNull);
      expect(profile.gazeOffsets['offsetY'], isNotNull);
    });

    test('should determine profile validity', () {
      final profile = CalibrationProfile.fromSession(testSession);

      // Should be valid with high confidence and completeness
      expect(profile.isValid, isTrue);
    });

    test('should provide quality rating', () {
      final profile = CalibrationProfile.fromSession(testSession);

      expect(profile.qualityRating, isIn(['Poor', 'Fair', 'Good', 'Excellent']));
    });

    test('should provide quality color', () {
      final profile = CalibrationProfile.fromSession(testSession);

      expect(profile.qualityColor, isA<int>());
      expect(profile.qualityColor, greaterThan(0));
    });

    test('should serialize to JSON', () {
      final profile = CalibrationProfile.fromSession(testSession);
      final json = profile.toJson();

      expect(json, contains('id'));
      expect(json, contains('userId'));
      expect(json, contains('qualityScore'));
      expect(json, contains('headPoseBaseline'));
      expect(json, contains('gazeOffsets'));
    });

    test('should deserialize from JSON', () {
      final profile = CalibrationProfile.fromSession(testSession);
      final json = profile.toJson();
      final deserialized = CalibrationProfile.fromJson(json);

      expect(deserialized.id, equals(profile.id));
      expect(deserialized.userId, equals(profile.userId));
      expect(deserialized.qualityScore, equals(profile.qualityScore));
    });
  });

  group('CalibrationProfile Edge Cases', () {
    test('should handle empty data points', () {
      final session = CalibrationSession(
        id: 'empty_session',
        userId: 'test_user',
        createdAt: DateTime.now(),
        modelId: 'yolo11_medium',
        cameraId: 'camera_1',
        dataPoints: [],
      );

      final profile = CalibrationProfile.fromSession(session);

      expect(profile.qualityScore, equals(0));
      expect(profile.averageConfidence, equals(0));
      expect(profile.completenessScore, equals(0));
      expect(profile.isValid, isFalse);
    });

    test('should handle low quality data', () {
      final lowQualityPoint = CalibrationDataPoint(
        targetPosition: const Offset(100, 100),
        tracking: ExtendedTrackingResult(
          faceDistance: 50.0,
          gazeAngleX: 0.1,
          gazeAngleY: 0.05,
          eyesFocused: false,
          headMoving: true,
          shouldersMoving: true,
          faceDetected: false, // Low quality: no face detected
          faceRect: null,
          faceLandmarks: [],
          leftEyeLandmarks: [],
          rightEyeLandmarks: [],
          headPose: const Vector3(0, 0, 0),
          gazeVector: const Vector3(0, 0, 1),
          confidence: 0.2, // Low confidence
        ),
        timestamp: DateTime.now(),
        dwellTime: const Duration(seconds: 3),
      );

      final session = CalibrationSession(
        id: 'low_quality_session',
        userId: 'test_user',
        createdAt: DateTime.now(),
        modelId: 'yolo11_medium',
        cameraId: 'camera_1',
        dataPoints: [lowQualityPoint],
      );

      final profile = CalibrationProfile.fromSession(session);

      expect(profile.isValid, isFalse);
      expect(profile.qualityRating, equals('Poor'));
    });
  });
}
