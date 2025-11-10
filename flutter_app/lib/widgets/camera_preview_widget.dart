import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera_macos/camera_macos.dart' as cam_macos;

class CameraPreviewWidget extends StatefulWidget {
  const CameraPreviewWidget({super.key});

  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget> {
  final GlobalKey _cameraKey = GlobalKey();
  cam_macos.CameraMacOSController? _macCameraController;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && Platform.isMacOS) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 300,
          child: cam_macos.CameraMacOSView(
            key: _cameraKey,
            fit: BoxFit.contain,
            cameraMode: cam_macos.CameraMacOSMode.video,
            onCameraInizialized: (cam_macos.CameraMacOSController controller) {
              setState(() {
                _macCameraController = controller;
              });
              print('Camera initialized successfully');
            },
          ),
        ),
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
