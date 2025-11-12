import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../services/camera_service.dart';
import '../services/model_registry.dart';
import '../models/model_info.dart';
import 'calibration_settings_dialog.dart';
import 'model_selection_dialog.dart';

/// Panel widget for calibration setup including camera selection, model selection,
/// and settings configuration before starting calibration.
class CalibrationSetupPanel extends StatelessWidget {
  final CalibrationSettings settings;
  final Function(CalibrationSettings) onSettingsChanged;
  final VoidCallback onStartCalibration;

  const CalibrationSetupPanel({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    required this.onStartCalibration,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Calibration Setup',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Camera selection
            _buildCameraSelector(context),
            const SizedBox(height: 16),

            // Model selection
            _buildModelSelector(context),
            const SizedBox(height: 24),

            const Divider(),
            const SizedBox(height: 16),

            // Quick settings summary
            _buildQuickSettings(),
            const SizedBox(height: 8),

            // Advanced settings button
            OutlinedButton.icon(
              onPressed: () => _showAdvancedSettings(context),
              icon: const Icon(Icons.settings),
              label: const Text('Advanced Settings'),
            ),
            const SizedBox(height: 24),

            // Start calibration button
            ElevatedButton.icon(
              onPressed: onStartCalibration,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Calibration'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraSelector(BuildContext context) {
    return Consumer<CameraService>(
      builder: (context, cameraService, child) {
        final availableCameras = cameraService.availableCameras;
        final selectedCamera = cameraService.selectedCamera;

        if (availableCameras.isEmpty) {
          return const ListTile(
            leading: Icon(Icons.videocam_off),
            title: Text('No cameras available'),
            subtitle: Text('Please connect a camera'),
          );
        }

        return ListTile(
          leading: const Icon(Icons.videocam),
          title: const Text('Camera'),
          subtitle: Text(selectedCamera?.name ?? 'None selected'),
          trailing: DropdownButton<CameraDescription>(
            value: selectedCamera,
            items: availableCameras.map((camera) {
              return DropdownMenuItem(
                value: camera,
                child: Text(_getCameraDisplayName(camera)),
              );
            }).toList(),
            onChanged: (camera) {
              if (camera != null) {
                cameraService.switchCamera(camera);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildModelSelector(BuildContext context) {
    return Consumer<CameraService>(
      builder: (context, cameraService, child) {
        final registry = ModelRegistry.instance;
        final currentModel = registry.getModelById(
          cameraService.selectedModelId ?? '',
        );
        final modelName = currentModel?.fullDisplayName ?? 'Default Model';

        return ListTile(
          leading: const Icon(Icons.memory),
          title: const Text('Detection Model'),
          subtitle: Text(modelName),
          trailing: IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: () => _showModelSelector(context),
          ),
          onTap: () => _showModelSelector(context),
        );
      },
    );
  }

  Widget _buildQuickSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Settings',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        // Circle duration
        _buildSettingItem(
          icon: Icons.timer,
          label: 'Circle Duration',
          value: '${settings.circleDuration} seconds',
        ),

        // Countdown
        _buildSettingItem(
          icon: settings.showCountdown ? Icons.check_circle : Icons.cancel,
          label: 'Countdown',
          value: settings.showCountdown ? 'Enabled' : 'Disabled',
        ),

        // TTS
        _buildSettingItem(
          icon: settings.enableTTS ? Icons.volume_up : Icons.volume_off,
          label: 'Voice Guidance',
          value: settings.enableTTS
              ? 'Enabled (${(settings.ttsSpeechRate * 100).round()}%)'
              : 'Disabled',
        ),
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Future<void> _showAdvancedSettings(BuildContext context) async {
    final newSettings = await showDialog<CalibrationSettings>(
      context: context,
      builder: (context) => CalibrationSettingsDialog(settings: settings),
    );

    if (newSettings != null) {
      onSettingsChanged(newSettings);
    }
  }

  Future<void> _showModelSelector(BuildContext context) async {
    final cameraService = Provider.of<CameraService>(context, listen: false);

    final selectedModel = await showDialog<ModelInfo>(
      context: context,
      builder: (context) => ModelSelectionDialog(
        currentModelId: cameraService.selectedModelId,
      ),
    );

    if (selectedModel != null) {
      final success = await cameraService.setModel(selectedModel.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Model changed to ${selectedModel.displayName}'
                  : 'Failed to change model',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _getCameraDisplayName(CameraDescription camera) {
    // Simplify camera names for better readability
    String name = camera.name;

    // Remove common prefixes
    name = name.replaceAll('com.apple.avfoundation.avcapturedevice.built-in_video:', '');
    name = name.replaceAll('Built-in', '').trim();

    // If empty or too long, use lens direction
    if (name.isEmpty || name.length > 30) {
      switch (camera.lensDirection) {
        case CameraLensDirection.front:
          return 'Front Camera';
        case CameraLensDirection.back:
          return 'Back Camera';
        case CameraLensDirection.external:
          return 'External Camera';
      }
    }

    return name;
  }
}
