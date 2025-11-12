import 'package:flutter/material.dart';

/// Settings for calibration customization
class CalibrationSettings {
  /// Duration each calibration circle is displayed (in seconds)
  final int circleDuration;

  /// Whether to show countdown before each point
  final bool showCountdown;

  /// Whether to show instructions overlay
  final bool showInstructions;

  /// Whether to show real-time data overlay
  final bool showDataOverlay;

  /// Whether to enable text-to-speech
  final bool enableTTS;

  /// TTS speech rate (0.0 slow to 1.0 fast)
  final double ttsSpeechRate;

  const CalibrationSettings({
    this.circleDuration = 3,
    this.showCountdown = true,
    this.showInstructions = true,
    this.showDataOverlay = false,
    this.enableTTS = false,
    this.ttsSpeechRate = 0.5,
  });

  CalibrationSettings copyWith({
    int? circleDuration,
    bool? showCountdown,
    bool? showInstructions,
    bool? showDataOverlay,
    bool? enableTTS,
    double? ttsSpeechRate,
  }) {
    return CalibrationSettings(
      circleDuration: circleDuration ?? this.circleDuration,
      showCountdown: showCountdown ?? this.showCountdown,
      showInstructions: showInstructions ?? this.showInstructions,
      showDataOverlay: showDataOverlay ?? this.showDataOverlay,
      enableTTS: enableTTS ?? this.enableTTS,
      ttsSpeechRate: ttsSpeechRate ?? this.ttsSpeechRate,
    );
  }
}

/// Dialog for customizing calibration settings
class CalibrationSettingsDialog extends StatefulWidget {
  /// Current settings
  final CalibrationSettings settings;

  const CalibrationSettingsDialog({
    super.key,
    required this.settings,
  });

  @override
  State<CalibrationSettingsDialog> createState() =>
      _CalibrationSettingsDialogState();
}

class _CalibrationSettingsDialogState
    extends State<CalibrationSettingsDialog> {
  late int _circleDuration;
  late bool _showCountdown;
  late bool _showInstructions;
  late bool _showDataOverlay;
  late bool _enableTTS;
  late double _ttsSpeechRate;

  @override
  void initState() {
    super.initState();
    _circleDuration = widget.settings.circleDuration;
    _showCountdown = widget.settings.showCountdown;
    _showInstructions = widget.settings.showInstructions;
    _showDataOverlay = widget.settings.showDataOverlay;
    _enableTTS = widget.settings.enableTTS;
    _ttsSpeechRate = widget.settings.ttsSpeechRate;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Calibration Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Circle Duration
            const Text(
              'Circle Duration',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'How long each calibration point stays visible',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _circleDuration.toDouble(),
                    min: 2,
                    max: 10,
                    divisions: 8,
                    label: '$_circleDuration seconds',
                    onChanged: (value) {
                      setState(() {
                        _circleDuration = value.round();
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    '$_circleDuration sec',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const Divider(height: 32),

            // Display Options
            const Text(
              'Display Options',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),

            // Countdown toggle
            SwitchListTile(
              title: const Text('Show Countdown'),
              subtitle: const Text('Display countdown before each point'),
              value: _showCountdown,
              onChanged: (value) {
                setState(() {
                  _showCountdown = value;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),

            // Instructions toggle
            SwitchListTile(
              title: const Text('Show Instructions'),
              subtitle: const Text('Display guidance and progress'),
              value: _showInstructions,
              onChanged: (value) {
                setState(() {
                  _showInstructions = value;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),

            // Data overlay toggle
            SwitchListTile(
              title: const Text('Show Tracking Data'),
              subtitle: const Text('Display real-time tracking metrics'),
              value: _showDataOverlay,
              onChanged: (value) {
                setState(() {
                  _showDataOverlay = value;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),

            const Divider(height: 32),

            // Text-to-Speech Options
            const Text(
              'Text-to-Speech',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),

            // TTS Enable/Disable toggle
            SwitchListTile(
              title: const Text('Enable Text-to-Speech'),
              subtitle: const Text('Spoken countdown and instructions'),
              value: _enableTTS,
              onChanged: (value) {
                setState(() {
                  _enableTTS = value;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),

            // TTS Speech Rate
            if (_enableTTS) ...[
              const SizedBox(height: 8),
              const Text(
                'Speech Rate',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _ttsSpeechRate,
                      min: 0.3,
                      max: 1.0,
                      divisions: 7,
                      label: '${(_ttsSpeechRate * 100).round()}%',
                      onChanged: (value) {
                        setState(() {
                          _ttsSpeechRate = value;
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${(_ttsSpeechRate * 100).round()}%',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final newSettings = CalibrationSettings(
              circleDuration: _circleDuration,
              showCountdown: _showCountdown,
              showInstructions: _showInstructions,
              showDataOverlay: _showDataOverlay,
              enableTTS: _enableTTS,
              ttsSpeechRate: _ttsSpeechRate,
            );
            Navigator.of(context).pop(newSettings);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
