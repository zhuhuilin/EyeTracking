import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../services/camera_service.dart';

class CalibrationPage extends StatefulWidget {
  const CalibrationPage({super.key});

  @override
  State<CalibrationPage> createState() => _CalibrationPageState();
}

class _CalibrationPageState extends State<CalibrationPage> {
  int _currentPoint = 0;
  bool _calibrating = false;
  Timer? _pointTimer;
  final List<Offset> _calibrationPoints = [
    const Offset(0.1, 0.1), // Top-left
    const Offset(0.9, 0.1), // Top-right
    const Offset(0.5, 0.5), // Center
    const Offset(0.1, 0.9), // Bottom-left
    const Offset(0.9, 0.9), // Bottom-right
  ];

  @override
  void dispose() {
    _pointTimer?.cancel();
    super.dispose();
  }

  void _startCalibration() {
    setState(() {
      _calibrating = true;
      _currentPoint = 0;
    });

    _showNextPoint();
  }

  void _showNextPoint() {
    if (_currentPoint >= _calibrationPoints.length) {
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
    final point = _calibrationPoints[_currentPoint];

    // Convert normalized coordinates to actual screen coordinates
    final size = MediaQuery.of(context).size;
    final screenX = point.dx * size.width;
    final screenY = point.dy * size.height;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Calibration failed: $e')),
      );
      setState(() {
        _calibrating = false;
      });
    }
  }

  void _cancelCalibration() {
    _pointTimer?.cancel();
    setState(() {
      _calibrating = false;
      _currentPoint = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eye Tracking Calibration'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          if (_calibrating)
            TextButton(
              onPressed: _cancelCalibration,
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
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
            if (_calibrating && _currentPoint < _calibrationPoints.length)
              Positioned(
                left: _calibrationPoints[_currentPoint].dx * size.width - 25,
                top: _calibrationPoints[_currentPoint].dy * size.height - 25,
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

            // Instructions
            Positioned(
              top: 20,
              left: 20,
              right: 20,
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
                          ? 'Look at the yellow circle and keep your eyes focused on it. The calibration will move through ${_calibrationPoints.length} points.'
                          : 'Calibration helps the eye tracker understand where you are looking on the screen. Follow the yellow circle with your eyes as it moves to different positions.',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    if (_calibrating) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: _currentPoint / _calibrationPoints.length,
                        backgroundColor: Colors.grey,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.yellow),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Point ${_currentPoint + 1} of ${_calibrationPoints.length}',
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
            if (_currentPoint >= _calibrationPoints.length && !_calibrating)
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
