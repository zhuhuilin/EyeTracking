import 'package:flutter/material.dart';
import 'package:camera/camera.dart' as cam;
import 'package:provider/provider.dart';

import '../services/camera_service.dart';

class CameraSelectionDialog extends StatefulWidget {
  const CameraSelectionDialog({super.key});

  @override
  State<CameraSelectionDialog> createState() => _CameraSelectionDialogState();
}

class _CameraSelectionDialogState extends State<CameraSelectionDialog> {
  List<cam.CameraDescription> _cameras = [];
  bool _isLoading = true;
  FaceDetectionBackend? _selectedBackend;

  @override
  void initState() {
    super.initState();
    _loadCameras();
  }

  Future<void> _loadCameras() async {
    try {
      final cameraService = Provider.of<CameraService>(context, listen: false);
      _cameras = await cameraService.detectCameras();
      _selectedBackend ??= cameraService.faceDetectionBackend;
    } catch (e) {
      print('Failed to load cameras: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getCameraDisplayName(cam.CameraDescription camera) {
    final direction = camera.lensDirection;
    String directionName;
    switch (direction) {
      case cam.CameraLensDirection.front:
        directionName = 'Front';
        break;
      case cam.CameraLensDirection.back:
        directionName = 'Back';
        break;
      case cam.CameraLensDirection.external:
        directionName = 'External';
        break;
      default:
        directionName = 'Unknown';
    }
    return '${camera.name} ($directionName)';
  }

  IconData _getCameraIcon(cam.CameraLensDirection direction) {
    switch (direction) {
      case cam.CameraLensDirection.front:
        return Icons.camera_front;
      case cam.CameraLensDirection.back:
        return Icons.camera_rear;
      case cam.CameraLensDirection.external:
        return Icons.videocam;
      default:
        return Icons.camera_alt;
    }
  }

  Future<void> _selectCamera(cam.CameraDescription camera) async {
    try {
      final cameraService = Provider.of<CameraService>(context, listen: false);
      await cameraService.switchCamera(camera);
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to switch camera: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.camera_alt),
          SizedBox(width: 8),
          Text('Select Camera'),
        ],
      ),
      content: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Detecting cameras...'),
                ],
              ),
            )
          : _cameras.isEmpty
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No cameras detected',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                )
              : SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 240,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _cameras.length,
                          itemBuilder: (context, index) {
                            final camera = _cameras[index];
                            final cameraService = Provider.of<CameraService>(
                                context,
                                listen: false);
                            final isSelected =
                                cameraService.selectedCamera?.name ==
                                    camera.name;

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              color: isSelected
                                  ? Colors.blue.withOpacity(0.1)
                                  : Colors.transparent,
                              child: ListTile(
                                leading: Icon(
                                  _getCameraIcon(camera.lensDirection),
                                  color: isSelected ? Colors.blue : Colors.grey,
                                ),
                                title: Text(
                                  _getCameraDisplayName(camera),
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color:
                                        isSelected ? Colors.blue : Colors.black,
                                  ),
                                ),
                                subtitle: Text(
                                  'Lens: ${camera.lensDirection.toString().split('.').last}',
                                  style: TextStyle(
                                    color:
                                        isSelected ? Colors.blue : Colors.grey,
                                  ),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle,
                                        color: Colors.blue)
                                    : null,
                                onTap: () => _selectCamera(camera),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildBackendSelector(),
                    ],
                  ),
                ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (_cameras.isNotEmpty)
          TextButton(
            onPressed: () {
              if (_cameras.isNotEmpty) {
                _selectCamera(_cameras.first);
              }
            },
            child: const Text('Use Default'),
          ),
      ],
    );
  }

  Widget _buildBackendSelector() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI Face Detection Model',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Consumer<CameraService>(
          builder: (context, cameraService, _) {
            final current =
                _selectedBackend ?? cameraService.faceDetectionBackend;
            return DropdownButtonFormField<FaceDetectionBackend>(
              initialValue: current,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: FaceDetectionBackend.values
                  .map(
                    (backend) => DropdownMenuItem(
                      value: backend,
                      child: Text(backend.label),
                    ),
                  )
                  .toList(),
              onChanged: (backend) async {
                if (backend == null) return;
                final service =
                    Provider.of<CameraService>(context, listen: false);
                await service.setFaceDetectionBackend(backend);
                if (!mounted) return;
                setState(() {
                  _selectedBackend = backend;
                });
              },
            );
          },
        ),
        const SizedBox(height: 6),
        const Text(
          'YOLO provides the highest accuracy. YuNet is balanced, Haar Cascade is the legacy fallback.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
