import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera_macos/camera_macos.dart' as cam_macos;

import '../services/camera_service.dart';

class CameraPreviewWidget extends StatefulWidget {
  const CameraPreviewWidget({super.key});

  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget> {
  cam_macos.CameraMacOSController? _macCameraController;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && Platform.isMacOS) {
      return Consumer<CameraService>(
        builder: (context, cameraService, child) {
          final selectedCamera = cameraService.selectedCamera;
          final deviceId = cameraService.selectedCameraDeviceId;

          // Use device ID as key to force rebuild when camera changes
          final cameraKey = deviceId != null
              ? ValueKey('camera_$deviceId')
              : const ValueKey('camera_default');

          return Card(
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: 300,
              child: cam_macos.CameraMacOSView(
                key: cameraKey,
                deviceId: deviceId, // Pass the device ID to specify which camera to use
                fit: BoxFit.contain,
                cameraMode: cam_macos.CameraMacOSMode.video,
                onCameraInizialized: (cam_macos.CameraMacOSController controller) {
                  setState(() {
                    _macCameraController = controller;
                  });
                  print('Camera initialized: ${selectedCamera?.name ?? "default"} (deviceId: $deviceId)');
                },
              ),
            ),
          );
        },
      );
    }

    return Card(
      child: SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Camera preview not available on this platform',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
