import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;

/// Circular countdown overlay that appears before each calibration point
/// Shows a countdown timer with a circular arc animation and optional flash effect
class CountdownOverlay extends StatefulWidget {
  /// Duration of the countdown in seconds
  final int durationSeconds;

  /// Whether to show a white flash when countdown reaches zero
  final bool showFlash;

  /// Callback when countdown completes
  final VoidCallback? onComplete;

  /// Position of the countdown (if null, centers on screen)
  final Offset? position;

  const CountdownOverlay({
    super.key,
    this.durationSeconds = 5,
    this.showFlash = true,
    this.onComplete,
    this.position,
  });

  @override
  State<CountdownOverlay> createState() => _CountdownOverlayState();
}

class _CountdownOverlayState extends State<CountdownOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _arcAnimation;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  bool _showingFlash = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.durationSeconds;

    // Arc animation controller (sweeps from 0 to 1 over full duration)
    _controller = AnimationController(
      duration: Duration(seconds: widget.durationSeconds),
      vsync: this,
    );

    _arcAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    // Start animations
    _controller.forward();

    // Update countdown numbers every second
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 1) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        _onCountdownComplete();
      }
    });
  }

  void _onCountdownComplete() {
    if (widget.showFlash) {
      setState(() {
        _showingFlash = true;
      });

      // Hide flash after 300ms
      Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _showingFlash = false;
          });
          widget.onComplete?.call();
        }
      });
    } else {
      widget.onComplete?.call();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Countdown circle
        Positioned(
          left: widget.position?.dx ?? (size.width / 2 - 75),
          top: widget.position?.dy ?? (size.height / 2 - 75),
          child: SizedBox(
            width: 150,
            height: 150,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _CountdownPainter(
                    progress: _arcAnimation.value,
                    remainingSeconds: _remainingSeconds,
                  ),
                );
              },
            ),
          ),
        ),

        // Flash effect
        if (_showingFlash)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _showingFlash ? 0.8 : 0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: Container(
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

/// Custom painter for the circular countdown animation
class _CountdownPainter extends CustomPainter {
  final double progress;
  final int remainingSeconds;

  _CountdownPainter({
    required this.progress,
    required this.remainingSeconds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Draw background circle
    final bgPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius + 5, bgPaint);

    // Draw progress arc
    final arcPaint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final startAngle = -math.pi / 2; // Start at top
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);

    // Draw remaining seconds text
    final textPainter = TextPainter(
      text: TextSpan(
        text: remainingSeconds.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 72,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(_CountdownPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.remainingSeconds != remainingSeconds;
  }
}
