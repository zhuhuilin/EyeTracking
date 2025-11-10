import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../services/camera_service.dart';

class CircleTestWidget extends StatefulWidget {
  final VoidCallback onTestComplete;

  const CircleTestWidget({super.key, required this.onTestComplete});

  @override
  State<CircleTestWidget> createState() => _CircleTestWidgetState();
}

class _CircleTestWidgetState extends State<CircleTestWidget> {
  Offset _circlePosition = Offset.zero;
  Offset _gazePosition = Offset.zero;
  Timer? _movementTimer;
  StreamSubscription<TrackingResult>? _trackingSubscription;
  Random _random = Random();
  int _currentTestPhase = 0; // 0: random, 1: horizontal, 2: vertical
  int _correctGazes = 0;
  int _totalGazes = 0;
  bool _testRunning = false;
  DateTime? _testStartTime;

  @override
  void initState() {
    super.initState();
    _random = Random();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTest();
    });
  }

  @override
  void dispose() {
    _movementTimer?.cancel();
    _trackingSubscription?.cancel();
    super.dispose();
  }

  void _initializeTest() {
    final size = MediaQuery.of(context).size;
    _circlePosition = Offset(size.width / 2, size.height / 2);
  }

  void _startTest() {
    setState(() {
      _testRunning = true;
      _testStartTime = DateTime.now();
      _currentTestPhase = 0;
      _correctGazes = 0;
      _totalGazes = 0;
    });

    // Start listening to tracking results
    final cameraService = Provider.of<CameraService>(context, listen: false);
    _trackingSubscription = cameraService.trackingResults.listen((result) {
      if (mounted && _testRunning) {
        _updateGazePosition(result);
        _checkGaze(_gazePosition);
      }
    });

    _startRandomMovement();
  }

  void _startRandomMovement() {
    _movementTimer?.cancel();
    _movementTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;

      setState(() {
        final size = MediaQuery.of(context).size;
        _circlePosition = Offset(
          _random.nextDouble() * (size.width - 100) + 50,
          _random.nextDouble() * (size.height - 100) + 50,
        );
      });
    });
  }

  void _startHorizontalMovement() {
    _movementTimer?.cancel();
    bool movingRight = true;

    _movementTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) return;

      setState(() {
        final size = MediaQuery.of(context).size;
        if (movingRight) {
          _circlePosition = Offset(_circlePosition.dx + 5, _circlePosition.dy);
          if (_circlePosition.dx > size.width - 50) {
            movingRight = false;
          }
        } else {
          _circlePosition = Offset(_circlePosition.dx - 5, _circlePosition.dy);
          if (_circlePosition.dx < 50) {
            movingRight = true;
          }
        }
      });
    });
  }

  void _startVerticalMovement() {
    _movementTimer?.cancel();
    bool movingDown = true;

    _movementTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) return;

      setState(() {
        final size = MediaQuery.of(context).size;
        if (movingDown) {
          _circlePosition = Offset(_circlePosition.dx, _circlePosition.dy + 5);
          if (_circlePosition.dy > size.height - 50) {
            movingDown = false;
          }
        } else {
          _circlePosition = Offset(_circlePosition.dx, _circlePosition.dy - 5);
          if (_circlePosition.dy < 50) {
            movingDown = true;
          }
        }
      });
    });
  }

  void _checkGaze(Offset gazePoint) {
    if (!_testRunning) return;

    _totalGazes++;

    // Check if gaze is within the circle
    final distance = _calculateDistance(gazePoint, _circlePosition);
    if (distance < 50) {
      // Within circle radius
      _correctGazes++;
    }

    // Check if we should move to next phase
    if (_totalGazes >= 50) {
      _nextPhase();
    }
  }

  void _nextPhase() {
    setState(() {
      _currentTestPhase++;
      _totalGazes = 0;
      _correctGazes = 0;
    });

    if (_currentTestPhase == 1) {
      _startHorizontalMovement();
    } else if (_currentTestPhase == 2) {
      _startVerticalMovement();
    } else if (_currentTestPhase >= 3) {
      _endTest();
    }
  }

  void _endTest() {
    _movementTimer?.cancel();
    setState(() {
      _testRunning = false;
    });
    widget.onTestComplete();
  }

  void _updateGazePosition(TrackingResult result) {
    if (!mounted) return;

    final size = MediaQuery.of(context).size;

    // Convert gaze angles to screen coordinates
    // Gaze angles are normalized (-1 to 1), convert to screen coordinates
    final screenX = size.width / 2 + (result.gazeAngleX * size.width / 4);
    final screenY = size.height / 2 + (result.gazeAngleY * size.height / 4);

    setState(() {
      _gazePosition = Offset(
        screenX.clamp(0.0, size.width),
        screenY.clamp(0.0, size.height),
      );
    });
  }

  double _calculateDistance(Offset p1, Offset p2) {
    return sqrt(pow(p1.dx - p2.dx, 2) + pow(p1.dy - p2.dy, 2));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background
        Container(color: Colors.grey[100]),

        // Moving circle
        Positioned(
          left: _circlePosition.dx - 25,
          top: _circlePosition.dy - 25,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
          ),
        ),

        // Test information overlay
        Positioned(
          top: 20,
          left: 20,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Test Phase: ${_getPhaseName(_currentTestPhase)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Accuracy: ${_totalGazes > 0 ? ((_correctGazes / _totalGazes) * 100).toStringAsFixed(1) : '0'}%',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gazes: $_correctGazes/$_totalGazes',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ),

        // Start button (only when test is not running)
        if (!_testRunning)
          Center(
            child: ElevatedButton.icon(
              onPressed: _startTest,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Tracking Test'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ),

        // Real-time gaze point
        if (_testRunning)
          Positioned(
            left: _gazePosition.dx - 10,
            top: _gazePosition.dy - 10,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _getPhaseName(int phase) {
    switch (phase) {
      case 0:
        return 'Random Movement';
      case 1:
        return 'Horizontal Movement';
      case 2:
        return 'Vertical Movement';
      default:
        return 'Complete';
    }
  }
}
