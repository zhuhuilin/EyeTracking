import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../services/camera_service.dart';

class CalibrationPage extends StatefulWidget {
  const CalibrationPage({super.key});

  @override
  State<CalibrationPage> createState() => _CalibrationPageState();
}

class _CalibrationPageState extends State<CalibrationPage> {
  static const MethodChannel _channel =
      MethodChannel('eyeball_tracking/camera');
  int _currentPoint = 0;
  bool _calibrating = false;
  Timer? _pointTimer;
  // Circle radius in pixels (25px for 50px diameter circle)
  static const double _circleRadius = 25.0;

  // Get calibration points that ensure circles are fully visible
  List<Offset> _getCalibrationPoints(Size screenSize) {
    return [
      // Top-left: position center so circle is fully visible
      Offset(_circleRadius, _circleRadius),
      // Top-right: position center so circle is fully visible
      Offset(screenSize.width - _circleRadius, _circleRadius),
      // Center
      Offset(screenSize.width / 2, screenSize.height / 2),
      // Bottom-left: position center so circle is fully visible
      Offset(_circleRadius, screenSize.height - _circleRadius),
      // Bottom-right: position center so circle is fully visible
      Offset(
          screenSize.width - _circleRadius, screenSize.height - _circleRadius),
    ];
  }

  @override
  void dispose() {
    _pointTimer?.cancel();
    super.dispose();
  }

  void _startCalibration() async {
    try {
      print('Attempting to save window state...');
      // Save current window state
      await _channel.invokeMethod('saveWindowState');
      print('Window state saved successfully');

      print('Attempting to enter fullscreen...');
      // Enter fullscreen mode
      await _channel.invokeMethod('enterFullscreen');
      print('Entered fullscreen successfully');

      setState(() {
        _calibrating = true;
        _currentPoint = 0;
      });

      _showNextPoint();
    } catch (e, stackTrace) {
      print('Calibration error: $e');
      print('Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to enter fullscreen: $e')),
      );
    }
  }

  void _showNextPoint() {
    final window = WidgetsBinding.instance.window;
    final screenSize = window.physicalSize / window.devicePixelRatio;
    final calibrationPoints = _getCalibrationPoints(screenSize);

    if (_currentPoint >= calibrationPoints.length) {
      _finishCalibration();
      return;
    }

    setState(() {
      // Update the UI to show the current point
    });

    // Show current calibration point for 3 seconds
    _pointTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _recordCalibrationPoint();
        setState(() {
          _currentPoint++;
        });
        _showNextPoint();
      }
    });
  }

  void _recordCalibrationPoint() async {
    final cameraService = Provider.of<CameraService>(context, listen: false);

    // Get screen size and calibration points
    final window = WidgetsBinding.instance.window;
    final screenSize = window.physicalSize / window.devicePixelRatio;
    final calibrationPoints = _getCalibrationPoints(screenSize);
    final point = calibrationPoints[_currentPoint];

    // Use absolute screen coordinates (no conversion needed since points are already in pixels)
    final screenX = point.dx;
    final screenY = point.dy;

    try {
      await cameraService.addCalibrationPoint(screenX, screenY);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Calibration error: $e')),
      );
    }
  }

  void _finishCalibration() async {
    final cameraService = Provider.of<CameraService>(context, listen: false);

    try {
      await cameraService.finishCalibration();

      // Restore window state
      await _channel.invokeMethod('restoreWindowState');

      setState(() {
        _calibrating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calibration completed successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back after a short delay
      Timer(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    } catch (e) {
      // Restore window state even on error
      try {
        await _channel.invokeMethod('restoreWindowState');
      } catch (restoreError) {
        // Ignore restore errors
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Calibration failed: $e')),
      );
      setState(() {
        _calibrating = false;
      });
    }
  }

  void _cancelCalibration() async {
    _pointTimer?.cancel();

    // Restore window state
    try {
      await _channel.invokeMethod('restoreWindowState');
    } catch (e) {
      // Ignore restore errors during cancel
    }

    setState(() {
      _calibrating = false;
      _currentPoint = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final window = WidgetsBinding.instance.window;
    final screenSize = window.physicalSize / window.devicePixelRatio;
    final calibrationPoints = _getCalibrationPoints(screenSize);

    return Scaffold(
      appBar: _calibrating
          ? null
          : AppBar(
              title: const Text('Eye Tracking Calibration'),
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
            ),
      body: Container(
        color: Colors.grey[900],
        child: Stack(
          children: [
            // Background grid for reference
            CustomPaint(
              painter: GridPainter(),
              size: size,
            ),

            // Calibration point
            if (_calibrating && _currentPoint < calibrationPoints.length)
              Positioned(
                left: calibrationPoints[_currentPoint].dx - _circleRadius,
                top: calibrationPoints[_currentPoint].dy - _circleRadius,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.yellow,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.visibility,
                    color: Colors.black,
                    size: 30,
                  ),
                ),
              ),

            // Cancel button (only during calibration)
            if (_calibrating)
              Positioned(
                top: 20,
                right: 20,
                child: FloatingActionButton(
                  onPressed: _cancelCalibration,
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.cancel, color: Colors.white),
                ),
              ),

            // Instructions
            Positioned(
              top: 20,
              left: 20,
              right: _calibrating ? 100 : 20, // Leave space for cancel button
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _calibrating
                          ? 'Calibration in Progress'
                          : 'Eye Tracking Calibration',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _calibrating
                          ? 'Look at the yellow circle and keep your eyes focused on it. The calibration will move through ${calibrationPoints.length} points.'
                          : 'Calibration helps the eye tracker understand where you are looking on the screen. Follow the yellow circle with your eyes as it moves to different positions.',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    if (_calibrating) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: _currentPoint / calibrationPoints.length,
                        backgroundColor: Colors.grey,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.yellow),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Point ${_currentPoint + 1} of ${calibrationPoints.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Start/Cancel button
            if (!_calibrating)
              Center(
                child: ElevatedButton.icon(
                  onPressed: _startCalibration,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Calibration'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    textStyle: const TextStyle(fontSize: 18),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

            // Completion message
            if (_currentPoint >= calibrationPoints.length && !_calibrating)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 48,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Calibration Complete!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Your eye tracking is now calibrated.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1;

    // Draw vertical lines
    for (double x = 0; x <= size.width; x += size.width / 10) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = 0; y <= size.height; y += size.height / 10) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
