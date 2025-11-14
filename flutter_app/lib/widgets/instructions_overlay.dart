import 'package:flutter/material.dart';

/// Semi-transparent overlay that displays calibration instructions and progress
class InstructionsOverlay extends StatelessWidget {
  /// Current instruction text to display
  final String instruction;

  /// Current calibration point number (1-indexed)
  final int currentPoint;

  /// Total number of calibration points
  final int totalPoints;

  /// Optional tip or guidance text
  final String? tip;

  /// Whether the overlay is visible
  final bool visible;

  /// Position: top or bottom of screen
  final InstructionPosition position;

  const InstructionsOverlay({
    super.key,
    required this.instruction,
    required this.currentPoint,
    required this.totalPoints,
    this.tip,
    this.visible = true,
    this.position = InstructionPosition.bottom,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;
    final isTop = position == InstructionPosition.top;

    return Positioned(
      left: 0,
      right: 0,
      top: isTop ? 40 : null,
      bottom: isTop ? null : 40,
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: size.width * 0.8,
            minWidth: 300,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 20,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.yellow.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Point $currentPoint of $totalPoints',
                    style: const TextStyle(
                      color: Colors.yellow,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: currentPoint / totalPoints,
                      backgroundColor: Colors.grey.withOpacity(0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.yellow,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Main instruction
              Text(
                instruction,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),

              // Optional tip
              if (tip != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lightbulb_outline,
                        color: Colors.lightBlueAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          tip!,
                          style: const TextStyle(
                            color: Colors.lightBlueAccent,
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Position of the instructions overlay
enum InstructionPosition {
  top,
  bottom,
}
