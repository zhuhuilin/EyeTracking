import 'dart:ui' show Offset;
import 'app_state.dart';

/// A 2D point for landmarks
class Point {
  final double x;
  final double y;

  const Point(this.x, this.y);

  Map<String, dynamic> toJson() {
    return {'x': x, 'y': y};
  }

  factory Point.fromJson(Map<String, dynamic> json) {
    return Point(
      (json['x'] as num).toDouble(),
      (json['y'] as num).toDouble(),
    );
  }

  @override
  String toString() => 'Point($x, $y)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Point &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}

/// A 3D vector for head pose and gaze direction
class Vector3 {
  final double x;
  final double y;
  final double z;

  const Vector3(this.x, this.y, this.z);

  Map<String, dynamic> toJson() {
    return {'x': x, 'y': y, 'z': z};
  }

  factory Vector3.fromJson(Map<String, dynamic> json) {
    return Vector3(
      (json['x'] as num).toDouble(),
      (json['y'] as num).toDouble(),
      (json['z'] as num).toDouble(),
    );
  }

  @override
  String toString() => 'Vector3($x, $y, $z)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vector3 &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          z == other.z;

  @override
  int get hashCode => x.hashCode ^ y.hashCode ^ z.hashCode;
}

/// Extended tracking result with comprehensive landmark data
class ExtendedTrackingResult extends TrackingResult {
  /// 68-point face landmarks (OpenCV dlib-style)
  final List<Point> faceLandmarks;

  /// Left eye landmarks (6 points, indices 36-41 from face landmarks)
  final List<Point> leftEyeLandmarks;

  /// Right eye landmarks (6 points, indices 42-47 from face landmarks)
  final List<Point> rightEyeLandmarks;

  /// Head pose in degrees (pitch, yaw, roll)
  final Vector3 headPose;

  /// Gaze vector (x, y, z) normalized direction
  final Vector3 gazeVector;

  /// Shoulder landmarks (optional, 2 points)
  final List<Point>? shoulderLandmarks;

  /// Detection confidence score (0.0 to 1.0)
  final double confidence;

  ExtendedTrackingResult({
    required super.faceDistance,
    required super.gazeAngleX,
    required super.gazeAngleY,
    required super.eyesFocused,
    required super.headMoving,
    required super.shouldersMoving,
    required super.faceDetected,
    super.faceRect,
    this.faceLandmarks = const [],
    this.leftEyeLandmarks = const [],
    this.rightEyeLandmarks = const [],
    this.headPose = const Vector3(0, 0, 0),
    this.gazeVector = const Vector3(0, 0, 1),
    this.shoulderLandmarks,
    this.confidence = 0.0,
  });

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['faceLandmarks'] = faceLandmarks.map((p) => p.toJson()).toList();
    json['leftEyeLandmarks'] = leftEyeLandmarks.map((p) => p.toJson()).toList();
    json['rightEyeLandmarks'] =
        rightEyeLandmarks.map((p) => p.toJson()).toList();
    json['headPose'] = headPose.toJson();
    json['gazeVector'] = gazeVector.toJson();
    json['shoulderLandmarks'] =
        shoulderLandmarks?.map((p) => p.toJson()).toList();
    json['confidence'] = confidence;
    return json;
  }

  factory ExtendedTrackingResult.fromJson(Map<String, dynamic> json) {
    final baseResult = TrackingResult.fromJson(json);

    return ExtendedTrackingResult(
      faceDistance: baseResult.faceDistance,
      gazeAngleX: baseResult.gazeAngleX,
      gazeAngleY: baseResult.gazeAngleY,
      eyesFocused: baseResult.eyesFocused,
      headMoving: baseResult.headMoving,
      shouldersMoving: baseResult.shouldersMoving,
      faceDetected: baseResult.faceDetected,
      faceRect: baseResult.faceRect,
      faceLandmarks: json['faceLandmarks'] != null
          ? (json['faceLandmarks'] as List)
              .map((p) => Point.fromJson(p as Map<String, dynamic>))
              .toList()
          : [],
      leftEyeLandmarks: json['leftEyeLandmarks'] != null
          ? (json['leftEyeLandmarks'] as List)
              .map((p) => Point.fromJson(p as Map<String, dynamic>))
              .toList()
          : [],
      rightEyeLandmarks: json['rightEyeLandmarks'] != null
          ? (json['rightEyeLandmarks'] as List)
              .map((p) => Point.fromJson(p as Map<String, dynamic>))
              .toList()
          : [],
      headPose: json['headPose'] != null
          ? Vector3.fromJson(json['headPose'] as Map<String, dynamic>)
          : const Vector3(0, 0, 0),
      gazeVector: json['gazeVector'] != null
          ? Vector3.fromJson(json['gazeVector'] as Map<String, dynamic>)
          : const Vector3(0, 0, 1),
      shoulderLandmarks: json['shoulderLandmarks'] != null
          ? (json['shoulderLandmarks'] as List)
              .map((p) => Point.fromJson(p as Map<String, dynamic>))
              .toList()
          : null,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Create from base TrackingResult with default extended values
  factory ExtendedTrackingResult.fromTrackingResult(TrackingResult result) {
    return ExtendedTrackingResult(
      faceDistance: result.faceDistance,
      gazeAngleX: result.gazeAngleX,
      gazeAngleY: result.gazeAngleY,
      eyesFocused: result.eyesFocused,
      headMoving: result.headMoving,
      shouldersMoving: result.shouldersMoving,
      faceDetected: result.faceDetected,
      faceRect: result.faceRect,
    );
  }
}

/// A single calibration data point capturing target position and tracking data
class CalibrationDataPoint {
  /// Where the calibration circle was displayed on screen
  final Offset targetPosition;

  /// Full tracking result captured at this calibration point
  final ExtendedTrackingResult tracking;

  /// When this data point was captured
  final DateTime timestamp;

  /// How long the user looked at this point (dwell time)
  final Duration dwellTime;

  CalibrationDataPoint({
    required this.targetPosition,
    required this.tracking,
    required this.timestamp,
    required this.dwellTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'targetPosition': {
        'x': targetPosition.dx,
        'y': targetPosition.dy,
      },
      'tracking': tracking.toJson(),
      'timestamp': timestamp.toIso8601String(),
      'dwellTime': dwellTime.inMilliseconds,
    };
  }

  factory CalibrationDataPoint.fromJson(Map<String, dynamic> json) {
    final targetPos = json['targetPosition'] as Map<String, dynamic>;
    return CalibrationDataPoint(
      targetPosition: Offset(
        (targetPos['x'] as num).toDouble(),
        (targetPos['y'] as num).toDouble(),
      ),
      tracking: ExtendedTrackingResult.fromJson(
          json['tracking'] as Map<String, dynamic>),
      timestamp: DateTime.parse(json['timestamp'] as String),
      dwellTime: Duration(milliseconds: json['dwellTime'] as int),
    );
  }
}

/// A complete calibration session with all data points and metadata
class CalibrationSession {
  /// Unique identifier for this calibration session
  final String id;

  /// User ID who performed this calibration
  final String userId;

  /// When this calibration session was created
  final DateTime createdAt;

  /// Model ID used during calibration
  final String modelId;

  /// Camera ID used during calibration
  final String cameraId;

  /// All calibration data points captured (typically 5 points)
  final List<CalibrationDataPoint> dataPoints;

  /// Quality score calculated after calibration (0-100)
  final double? qualityScore;

  /// Additional metadata
  final Map<String, dynamic> metadata;

  CalibrationSession({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.modelId,
    required this.cameraId,
    this.dataPoints = const [],
    this.qualityScore,
    this.metadata = const {},
  });

  /// Calculate quality score based on calibration data
  double calculateQualityScore() {
    if (dataPoints.isEmpty) return 0.0;

    // Average confidence across all points
    final avgConfidence = dataPoints
            .map((p) => p.tracking.confidence)
            .reduce((a, b) => a + b) /
        dataPoints.length;

    // Count how many points had face detected
    final faceDetectedCount =
        dataPoints.where((p) => p.tracking.faceDetected).length;
    final completenessScore = faceDetectedCount / dataPoints.length;

    // Head pose consistency (lower variance is better)
    final pitchValues = dataPoints.map((p) => p.tracking.headPose.x).toList();
    final yawValues = dataPoints.map((p) => p.tracking.headPose.y).toList();
    final rollValues = dataPoints.map((p) => p.tracking.headPose.z).toList();

    double calculateVariance(List<double> values) {
      if (values.isEmpty) return 0.0;
      final mean = values.reduce((a, b) => a + b) / values.length;
      final variance = values
              .map((v) => (v - mean) * (v - mean))
              .reduce((a, b) => a + b) /
          values.length;
      return variance;
    }

    final pitchVariance = calculateVariance(pitchValues);
    final yawVariance = calculateVariance(yawValues);
    final rollVariance = calculateVariance(rollValues);
    final avgVariance = (pitchVariance + yawVariance + rollVariance) / 3;

    // Consistency score: high variance = low score
    // Typical head pose variance during calibration should be < 25 degrees
    final consistencyScore =
        (1.0 - (avgVariance / 625.0).clamp(0.0, 1.0)).clamp(0.0, 1.0);

    // Combined quality score (weighted)
    final quality = (0.4 * avgConfidence +
            0.3 * consistencyScore +
            0.3 * completenessScore) *
        100.0;

    return quality.clamp(0.0, 100.0);
  }

  /// Create a copy with updated quality score
  CalibrationSession withQualityScore(double score) {
    return CalibrationSession(
      id: id,
      userId: userId,
      createdAt: createdAt,
      modelId: modelId,
      cameraId: cameraId,
      dataPoints: dataPoints,
      qualityScore: score,
      metadata: metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'modelId': modelId,
      'cameraId': cameraId,
      'dataPoints': dataPoints.map((p) => p.toJson()).toList(),
      'qualityScore': qualityScore,
      'metadata': metadata,
    };
  }

  factory CalibrationSession.fromJson(Map<String, dynamic> json) {
    return CalibrationSession(
      id: json['id'] as String,
      userId: json['userId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      modelId: json['modelId'] as String,
      cameraId: json['cameraId'] as String,
      dataPoints: (json['dataPoints'] as List)
          .map((p) => CalibrationDataPoint.fromJson(p as Map<String, dynamic>))
          .toList(),
      qualityScore: (json['qualityScore'] as num?)?.toDouble(),
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }
}
