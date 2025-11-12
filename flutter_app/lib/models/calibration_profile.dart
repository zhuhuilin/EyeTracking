import 'calibration_data.dart';

/// Represents a user's calibration profile containing correction parameters
/// and quality metrics. Used to improve real-time tracking accuracy.
class CalibrationProfile {
  final String id;
  final String userId;
  final DateTime createdAt;
  final String modelId; // Model used for calibration
  final String cameraId; // Camera used for calibration

  // Calibration data points
  final List<CalibrationDataPoint> dataPoints;

  // Quality metrics
  final double qualityScore; // 0-100
  final double averageConfidence; // 0.0-1.0
  final double headPoseConsistency; // Lower variance = better
  final double completenessScore; // Percentage of successful points

  // Correction parameters (simplified for Phase 6)
  final Vector3 headPoseBaseline; // User's neutral head position
  final Map<String, double> gazeOffsets; // Simple X/Y offset corrections

  // Metadata
  final Map<String, dynamic> metadata;

  const CalibrationProfile({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.modelId,
    required this.cameraId,
    required this.dataPoints,
    required this.qualityScore,
    required this.averageConfidence,
    required this.headPoseConsistency,
    required this.completenessScore,
    required this.headPoseBaseline,
    required this.gazeOffsets,
    this.metadata = const {},
  });

  /// Creates a calibration profile from a calibration session
  factory CalibrationProfile.fromSession(CalibrationSession session) {
    // Calculate quality metrics
    final qualityScore = session.calculateQualityScore();
    final averageConfidence = _calculateAverageConfidence(session.dataPoints);
    final headPoseConsistency = _calculateHeadPoseConsistency(session.dataPoints);
    final completenessScore = _calculateCompletenessScore(session.dataPoints);

    // Calculate baseline head pose (average of all points)
    final headPoseBaseline = _calculateHeadPoseBaseline(session.dataPoints);

    // Calculate simple gaze offsets (deferred complex algorithms to future)
    final gazeOffsets = _calculateGazeOffsets(session.dataPoints);

    return CalibrationProfile(
      id: session.id,
      userId: session.userId,
      createdAt: session.createdAt,
      modelId: session.modelId,
      cameraId: session.cameraId,
      dataPoints: session.dataPoints,
      qualityScore: qualityScore,
      averageConfidence: averageConfidence,
      headPoseConsistency: headPoseConsistency,
      completenessScore: completenessScore,
      headPoseBaseline: headPoseBaseline,
      gazeOffsets: gazeOffsets,
      metadata: session.metadata,
    );
  }

  // Quality calculation helpers

  static double _calculateAverageConfidence(List<CalibrationDataPoint> points) {
    if (points.isEmpty) return 0.0;

    final validPoints = points.where((p) => p.tracking.confidence > 0).toList();
    if (validPoints.isEmpty) return 0.0;

    final sum = validPoints.fold(0.0, (sum, point) => sum + point.tracking.confidence);
    return sum / validPoints.length;
  }

  static double _calculateHeadPoseConsistency(List<CalibrationDataPoint> points) {
    if (points.length < 2) return 1.0;

    // Calculate variance in head pose
    final pitchValues = points.map((p) => p.tracking.headPose.x).toList();
    final yawValues = points.map((p) => p.tracking.headPose.y).toList();
    final rollValues = points.map((p) => p.tracking.headPose.z).toList();

    final pitchVariance = _calculateVariance(pitchValues);
    final yawVariance = _calculateVariance(yawValues);
    final rollVariance = _calculateVariance(rollValues);

    // Average variance (lower = more consistent)
    final avgVariance = (pitchVariance + yawVariance + rollVariance) / 3.0;

    // Convert to score (0-1, where 1 is perfect consistency)
    // Variance of 0 = score 1.0, variance of 100 = score 0.0
    return 1.0 - (avgVariance / 100.0).clamp(0.0, 1.0);
  }

  static double _calculateCompletenessScore(List<CalibrationDataPoint> points) {
    if (points.isEmpty) return 0.0;

    final successfulPoints = points.where((p) =>
      p.tracking.faceDetected &&
      p.tracking.confidence > 0.5
    ).length;

    return successfulPoints / points.length;
  }

  static Vector3 _calculateHeadPoseBaseline(List<CalibrationDataPoint> points) {
    if (points.isEmpty) {
      return const Vector3(0, 0, 0);
    }

    final avgPitch = points.fold(0.0, (sum, p) => sum + p.tracking.headPose.x) / points.length;
    final avgYaw = points.fold(0.0, (sum, p) => sum + p.tracking.headPose.y) / points.length;
    final avgRoll = points.fold(0.0, (sum, p) => sum + p.tracking.headPose.z) / points.length;

    return Vector3(avgPitch, avgYaw, avgRoll);
  }

  static Map<String, double> _calculateGazeOffsets(List<CalibrationDataPoint> points) {
    if (points.isEmpty) {
      return {'offsetX': 0.0, 'offsetY': 0.0};
    }

    // Simple average offset (future: polynomial mapping)
    final avgOffsetX = points.fold(0.0, (sum, p) => sum + p.tracking.gazeVector.x) / points.length;
    final avgOffsetY = points.fold(0.0, (sum, p) => sum + p.tracking.gazeVector.y) / points.length;

    return {
      'offsetX': avgOffsetX,
      'offsetY': avgOffsetY,
    };
  }

  static double _calculateVariance(List<double> values) {
    if (values.length < 2) return 0.0;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => (v - mean) * (v - mean));
    return squaredDiffs.reduce((a, b) => a + b) / values.length;
  }

  // Serialization

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'modelId': modelId,
      'cameraId': cameraId,
      'dataPoints': dataPoints.map((p) => p.toJson()).toList(),
      'qualityScore': qualityScore,
      'averageConfidence': averageConfidence,
      'headPoseConsistency': headPoseConsistency,
      'completenessScore': completenessScore,
      'headPoseBaseline': {
        'x': headPoseBaseline.x,
        'y': headPoseBaseline.y,
        'z': headPoseBaseline.z,
      },
      'gazeOffsets': gazeOffsets,
      'metadata': metadata,
    };
  }

  factory CalibrationProfile.fromJson(Map<String, dynamic> json) {
    return CalibrationProfile(
      id: json['id'] as String,
      userId: json['userId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      modelId: json['modelId'] as String,
      cameraId: json['cameraId'] as String,
      dataPoints: (json['dataPoints'] as List)
          .map((p) => CalibrationDataPoint.fromJson(p as Map<String, dynamic>))
          .toList(),
      qualityScore: (json['qualityScore'] as num).toDouble(),
      averageConfidence: (json['averageConfidence'] as num).toDouble(),
      headPoseConsistency: (json['headPoseConsistency'] as num).toDouble(),
      completenessScore: (json['completenessScore'] as num).toDouble(),
      headPoseBaseline: Vector3.fromJson(json['headPoseBaseline'] as Map<String, dynamic>),
      gazeOffsets: Map<String, double>.from(json['gazeOffsets'] as Map),
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Determines if this calibration profile is good enough to use
  bool get isValid {
    return qualityScore >= 50.0 &&
           averageConfidence >= 0.5 &&
           completenessScore >= 0.6;
  }

  /// Gets a human-readable quality rating
  String get qualityRating {
    if (qualityScore >= 80) return 'Excellent';
    if (qualityScore >= 60) return 'Good';
    if (qualityScore >= 40) return 'Fair';
    return 'Poor';
  }

  /// Gets a color representing the quality
  /// Returns color value as int (0xAARRGGBB)
  int get qualityColor {
    if (qualityScore >= 80) return 0xFF4CAF50; // Green
    if (qualityScore >= 60) return 0xFF8BC34A; // Light green
    if (qualityScore >= 40) return 0xFFFFC107; // Amber
    return 0xFFF44336; // Red
  }

  @override
  String toString() {
    return 'CalibrationProfile(id: $id, quality: ${qualityScore.toStringAsFixed(1)}, '
           'rating: $qualityRating, confidence: ${(averageConfidence * 100).toStringAsFixed(1)}%)';
  }
}
