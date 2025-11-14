import 'package:flutter/material.dart';
import '../models/calibration_data.dart';

/// Displays real-time tracking data during calibration
/// Shows face distance, head pose, gaze angles, and confidence with color coding
class CalibrationDataOverlay extends StatelessWidget {
  /// Current tracking result to display
  final ExtendedTrackingResult? trackingResult;

  /// Whether the overlay is visible
  final bool visible;

  /// Position of the overlay
  final DataOverlayPosition position;

  const CalibrationDataOverlay({
    super.key,
    this.trackingResult,
    this.visible = true,
    this.position = DataOverlayPosition.topRight,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final result = trackingResult;
    if (result == null || !result.faceDetected) {
      return _buildNoDataOverlay();
    }

    return _buildDataOverlay(result);
  }

  Widget _buildNoDataOverlay() {
    final positionConstraints = _getPositionConstraints();
    return Positioned(
      top: positionConstraints['top'],
      bottom: positionConstraints['bottom'],
      left: positionConstraints['left'],
      right: positionConstraints['right'],
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _overlayDecoration(),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 16),
                SizedBox(width: 8),
                Text(
                  'No Face Detected',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataOverlay(ExtendedTrackingResult result) {
    final positionConstraints = _getPositionConstraints();
    return Positioned(
      top: positionConstraints['top'],
      bottom: positionConstraints['bottom'],
      left: positionConstraints['left'],
      right: positionConstraints['right'],
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _overlayDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            const Text(
              'Tracking Data',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Face Distance
            _buildDataRow(
              'Distance',
              '${result.faceDistance.toStringAsFixed(0)} cm',
              _getDistanceQuality(result.faceDistance),
            ),

            const SizedBox(height: 4),

            // Head Pose
            _buildDataRow(
              'Pitch',
              '${result.headPose.x.toStringAsFixed(1)}°',
              _getAngleQuality(result.headPose.x),
            ),
            _buildDataRow(
              'Yaw',
              '${result.headPose.y.toStringAsFixed(1)}°',
              _getAngleQuality(result.headPose.y),
            ),
            _buildDataRow(
              'Roll',
              '${result.headPose.z.toStringAsFixed(1)}°',
              _getAngleQuality(result.headPose.z),
            ),

            const SizedBox(height: 4),

            // Gaze Angles
            _buildDataRow(
              'Gaze X',
              '${result.gazeAngleX.toStringAsFixed(2)}',
              _getGazeQuality(result.gazeAngleX),
            ),
            _buildDataRow(
              'Gaze Y',
              '${result.gazeAngleY.toStringAsFixed(2)}',
              _getGazeQuality(result.gazeAngleY),
            ),

            const SizedBox(height: 4),

            // Confidence
            _buildDataRow(
              'Confidence',
              '${(result.confidence * 100).toStringAsFixed(0)}%',
              _getConfidenceQuality(result.confidence),
            ),

            const SizedBox(height: 4),

            // Landmarks count
            if (result.faceLandmarks.isNotEmpty)
              Text(
                '${result.faceLandmarks.length} landmarks',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value, DataQuality quality) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        _buildQualityIndicator(quality),
      ],
    );
  }

  Widget _buildQualityIndicator(DataQuality quality) {
    Color color;
    switch (quality) {
      case DataQuality.good:
        color = Colors.green;
        break;
      case DataQuality.fair:
        color = Colors.yellow;
        break;
      case DataQuality.poor:
        color = Colors.red;
        break;
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  BoxDecoration _overlayDecoration() {
    return BoxDecoration(
      color: Colors.black.withOpacity(0.7),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Colors.white.withOpacity(0.2),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.5),
          blurRadius: 10,
          spreadRadius: 2,
        ),
      ],
    );
  }

  Map<String, double?> _getPositionConstraints() {
    switch (position) {
      case DataOverlayPosition.topRight:
        return {'top': 80.0, 'right': 20.0};
      case DataOverlayPosition.topLeft:
        return {'top': 80.0, 'left': 20.0};
      case DataOverlayPosition.bottomRight:
        return {'bottom': 80.0, 'right': 20.0};
      case DataOverlayPosition.bottomLeft:
        return {'bottom': 80.0, 'left': 20.0};
    }
  }

  DataQuality _getDistanceQuality(double distance) {
    if (distance >= 40 && distance <= 60) return DataQuality.good;
    if (distance >= 30 && distance <= 70) return DataQuality.fair;
    return DataQuality.poor;
  }

  DataQuality _getAngleQuality(double angle) {
    final absAngle = angle.abs();
    if (absAngle <= 10) return DataQuality.good;
    if (absAngle <= 20) return DataQuality.fair;
    return DataQuality.poor;
  }

  DataQuality _getGazeQuality(double gaze) {
    final absGaze = gaze.abs();
    if (absGaze <= 0.1) return DataQuality.good;
    if (absGaze <= 0.2) return DataQuality.fair;
    return DataQuality.poor;
  }

  DataQuality _getConfidenceQuality(double confidence) {
    if (confidence >= 0.8) return DataQuality.good;
    if (confidence >= 0.5) return DataQuality.fair;
    return DataQuality.poor;
  }
}

/// Position options for the data overlay
enum DataOverlayPosition {
  topRight,
  topLeft,
  bottomRight,
  bottomLeft,
}

/// Quality indicator for tracking data
enum DataQuality {
  good,
  fair,
  poor,
}
