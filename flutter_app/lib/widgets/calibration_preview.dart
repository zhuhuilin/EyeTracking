import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../services/camera_service.dart';

/// Widget that displays a live camera preview with face detection overlays
/// before calibration begins. Shows real-time tracking to help users verify
/// their setup.
class CalibrationPreview extends StatefulWidget {
  const CalibrationPreview({super.key});

  @override
  State<CalibrationPreview> createState() => _CalibrationPreviewState();
}

class _CalibrationPreviewState extends State<CalibrationPreview> {
  @override
  Widget build(BuildContext context) {
    return Consumer<CameraService>(
      builder: (context, cameraService, child) {
        final controller = cameraService.cameraController;

        if (controller == null || !controller.value.isInitialized) {
          return _buildPlaceholder('Camera not initialized');
        }

        final trackingResult = cameraService.latestTrackingResult;

        return AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Camera preview
              CameraPreview(controller),

              // Face detection overlay
              if (trackingResult == null || !trackingResult.faceDetected)
                _buildNoFaceOverlay()
              else
                _buildTrackingOverlay(trackingResult),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder(String message) {
    return Container(
      width: 640,
      height: 480,
      color: Colors.grey[900],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.videocam_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoFaceOverlay() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'No Face Detected',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingOverlay(TrackingResult trackingResult) {
    return CustomPaint(
      painter: _FaceDetectionPainter(trackingResult),
    );
  }
}

/// Custom painter for drawing face detection box and tracking info
class _FaceDetectionPainter extends CustomPainter {
  final TrackingResult trackingResult;

  _FaceDetectionPainter(this.trackingResult);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw face bounding box
    if (trackingResult.faceDetected && trackingResult.faceRect != null) {
      final faceRectData = trackingResult.faceRect!;
      final faceRect = Rect.fromLTWH(
        faceRectData.left * size.width,
        faceRectData.top * size.height,
        faceRectData.width * size.width,
        faceRectData.height * size.height,
      );

      // Determine box color based on tracking quality
      Color boxColor = Colors.green;
      if (trackingResult.headMoving) {
        boxColor = Colors.orange;
      }
      if (!trackingResult.eyesFocused) {
        boxColor = Colors.yellow;
      }

      final paint = Paint()
        ..color = boxColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      canvas.drawRect(faceRect, paint);

      // Draw corner accents for better visibility
      _drawCornerAccents(canvas, faceRect, boxColor);

      // Draw tracking info text
      _drawTrackingInfo(canvas, size, trackingResult);
    }
  }

  void _drawCornerAccents(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const cornerLength = 20.0;

    // Top-left
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left + cornerLength, rect.top),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left, rect.top + cornerLength),
      paint,
    );

    // Top-right
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right - cornerLength, rect.top),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.top + cornerLength),
      paint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left + cornerLength, rect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left, rect.bottom - cornerLength),
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right - cornerLength, rect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right, rect.bottom - cornerLength),
      paint,
    );
  }

  void _drawTrackingInfo(Canvas canvas, Size size, TrackingResult result) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );

    // Distance info
    final distanceText = 'Distance: ${result.faceDistance.toStringAsFixed(1)} cm';
    final statusText = result.eyesFocused ? 'Eyes Focused' : 'Look at Camera';

    final infoText = '$distanceText\n$statusText';

    textPainter.text = TextSpan(
      text: infoText,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            blurRadius: 4,
            color: Colors.black,
            offset: Offset(1, 1),
          ),
        ],
      ),
    );

    textPainter.layout();

    // Draw in top-left corner
    textPainter.paint(canvas, const Offset(16, 16));
  }

  @override
  bool shouldRepaint(_FaceDetectionPainter oldDelegate) {
    return oldDelegate.trackingResult != trackingResult;
  }
}
