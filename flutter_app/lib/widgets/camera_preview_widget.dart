import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera_macos/camera_macos.dart' as cam_macos;

import '../models/app_state.dart';
import '../services/camera_service.dart';

class CameraPreviewWidget extends StatefulWidget {
  const CameraPreviewWidget({super.key});

  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget> {
  bool _showDetectionOverlay = true;
  bool _trackingStartRequested = false;
  bool _autoStartAttempted = false;
  bool _initializingCamera = false;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && Platform.isMacOS) {
      return Consumer<CameraService>(
        builder: (context, cameraService, child) {
          final selectedCamera = cameraService.selectedCamera;
          final deviceId = cameraService.selectedCameraDeviceId;
          final trackingResult = cameraService.latestTrackingResult;

          _ensureInitialized(cameraService);
          _ensureTracking(cameraService);

          // Use device ID as key to force rebuild when camera changes
          final cameraKey = deviceId != null
              ? ValueKey('camera_$deviceId')
              : const ValueKey('camera_default');

          debugPrint('[CameraPreview] Building CameraMacOSView with deviceId: $deviceId');

          final preview = Stack(
            children: [
              cam_macos.CameraMacOSView(
                key: cameraKey,
                deviceId: deviceId, // Specify which camera to use
                fit: BoxFit.cover,
                cameraMode: cam_macos.CameraMacOSMode.video,
                onCameraInizialized: (cam_macos.CameraMacOSController controller) {
                  debugPrint('[CameraPreview] onCameraInizialized callback triggered!');
                  debugPrint('[CameraPreview] Camera: ${selectedCamera?.name ?? "default"} (deviceId: $deviceId)');
                  debugPrint('[CameraPreview] Attaching controller to camera service...');
                  cameraService.attachMacCameraController(controller).catchError(
                    (error, stack) {
                      debugPrint('[CameraPreview] Failed to attach mac camera: $error');
                      debugPrint('$stack');
                    },
                  ).then((_) {
                    debugPrint('[CameraPreview] Controller attached successfully');
                  });
                },
              ),
              // Debug overlay to confirm widget is rendering
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.red.withOpacity(0.7),
                  child: Text(
                    'Camera Preview Active\nDevice: ${deviceId ?? "default"}',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
            ],
          );

          return Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 300,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final overlayChildren = <Widget>[
                        Positioned.fill(child: preview),
                      ];

                      final faceRect = _resolveFaceRect(
                        trackingResult,
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      final faceDistance = trackingResult?.faceDistance;
                      final faceDetected = trackingResult?.faceDetected ?? false;

                      // Get color based on active backend
                      final backendColor = _getBackendColor(cameraService.faceDetectionBackend);
                      final backendLabel = _getBackendLabel(cameraService.faceDetectionBackend);

                      if (_showDetectionOverlay && faceRect != null) {
                        overlayChildren.add(
                          Positioned(
                            left: faceRect.left,
                            top: faceRect.top,
                            width: faceRect.width,
                            height: faceRect.height,
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: backendColor,
                                    width: 3,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        );

                        overlayChildren.add(
                          Positioned(
                            left: faceRect.left,
                            top: (faceRect.top - 28).clamp(0.0, constraints.maxHeight - 28),
                            child: _FaceLabel(
                              text: backendLabel,
                              color: backendColor,
                            ),
                          ),
                        );
                      }

                      overlayChildren.add(
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: _FaceDistanceChip(
                            distanceCm: faceDetected ? faceDistance : null,
                            trackingActive: cameraService.isTracking,
                          ),
                        ),
                      );

                      return Stack(children: overlayChildren);
                    },
                  ),
                ),
                _PreviewControls(
                  showOverlay: _showDetectionOverlay,
                  trackingActive: cameraService.isTracking,
                  backend: cameraService.faceDetectionBackend,
                  onToggleOverlay: () {
                    setState(() {
                      _showDetectionOverlay = !_showDetectionOverlay;
                    });
                  },
                  onToggleTracking: () async {
                    if (cameraService.isTracking) {
                      await cameraService.stopTracking();
                      setState(() {
                        _trackingStartRequested = false;
                        _autoStartAttempted = true;
                      });
                    } else {
                      try {
                        await cameraService.startTracking();
                        setState(() {
                          _trackingStartRequested = true;
                          _autoStartAttempted = true;
                        });
                      } catch (e) {
                        debugPrint('Manual start tracking failed: $e');
                        setState(() {
                          _trackingStartRequested = false;
                        });
                      }
                    }
                  },
                  onSelectBackend: () => _showBackendSelector(cameraService),
                ),
              ],
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

  void _ensureTracking(CameraService service) {
    if (_autoStartAttempted) return;
    if (_trackingStartRequested) return;
    if (service.isTracking) return;
    if (!service.isInitialized) return;
    if (Platform.isMacOS && !service.hasMacCameraController) {
      return;
    }
    _trackingStartRequested = true;
    Future.microtask(() async {
      try {
        await service.startTracking();
        setState(() {
          _autoStartAttempted = true;
        });
      } catch (e) {
        debugPrint('Auto start tracking failed: $e');
        setState(() {
          _trackingStartRequested = false;
          _autoStartAttempted = true;
        });
      }
    });
  }

  void _ensureInitialized(CameraService service) {
    if (service.isInitialized || _initializingCamera) return;
    _initializingCamera = true;
    Future.microtask(() async {
      try {
        await service.initialize();
      } catch (e) {
        debugPrint('Camera initialize failed: $e');
      } finally {
        if (mounted) {
          setState(() {
            _initializingCamera = false;
          });
        } else {
          _initializingCamera = false;
        }
      }
    });
  }

  Future<void> _showBackendSelector(CameraService service) async {
    if (!mounted) return;
    final selected = await showModalBottomSheet<FaceDetectionBackend>(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Select AI Model',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final backend in FaceDetectionBackend.values)
              RadioListTile<FaceDetectionBackend>(
                title: Text(backend.label),
                value: backend,
                groupValue: service.faceDetectionBackend,
                onChanged: (value) => Navigator.of(context).pop(value),
              ),
            const SizedBox(height: 8),
          ],
        );
      },
    );

    if (selected != null) {
      await service.setFaceDetectionBackend(selected);
      if (mounted) {
        setState(() {});
      }
    }
  }

  Color _getBackendColor(FaceDetectionBackend backend) {
    switch (backend) {
      case FaceDetectionBackend.yunet:
        return Colors.cyanAccent;  // Bright cyan for YuNet
      case FaceDetectionBackend.haar:
        return Colors.greenAccent;  // Green for Haar Cascade
      case FaceDetectionBackend.yolo:
        return Colors.purpleAccent;  // Purple for YOLO
      case FaceDetectionBackend.auto:
      default:
        return Colors.orangeAccent;  // Orange for Auto mode
    }
  }

  String _getBackendLabel(FaceDetectionBackend backend) {
    switch (backend) {
      case FaceDetectionBackend.yunet:
        return 'YuNet';
      case FaceDetectionBackend.haar:
        return 'Haar';
      case FaceDetectionBackend.yolo:
        return 'YOLO';
      case FaceDetectionBackend.auto:
      default:
        return 'Auto';
    }
  }
}

Rect? _resolveFaceRect(
  TrackingResult? result,
  double maxWidth,
  double maxHeight,
) {
  if (result == null || !result.faceDetected || result.faceRect == null) {
    return null;
  }

  final normalized = result.faceRect!;
  final left = (normalized.left.clamp(0.0, 1.0)) * maxWidth;
  final top = (normalized.top.clamp(0.0, 1.0)) * maxHeight;
  final width = (normalized.width.clamp(0.0, 1.0)) * maxWidth;
  final height = (normalized.height.clamp(0.0, 1.0)) * maxHeight;

  if (width <= 0 || height <= 0) {
    return null;
  }

  final clampedLeft = left.clamp(0.0, maxWidth - width);
  final clampedTop = top.clamp(0.0, maxHeight - height);

  return Rect.fromLTWH(clampedLeft, clampedTop, width, height);
}

class _FaceDistanceChip extends StatelessWidget {
  final double? distanceCm;
  final bool trackingActive;

  const _FaceDistanceChip({required this.distanceCm, required this.trackingActive});

  @override
  Widget build(BuildContext context) {
    final hasDistance = distanceCm != null && distanceCm!.isFinite;
    final displayText = trackingActive
        ? (hasDistance ? '${distanceCm!.toStringAsFixed(1)} cm' : 'No face detected')
        : 'Tracking not running';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasDistance ? Icons.face_retouching_natural : Icons.face_retouching_off,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            displayText,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _FaceLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _FaceLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _PreviewControls extends StatelessWidget {
  final bool showOverlay;
  final bool trackingActive;
  final VoidCallback onToggleOverlay;
  final Future<void> Function() onToggleTracking;
  final FaceDetectionBackend backend;
  final Future<void> Function() onSelectBackend;

  const _PreviewControls({
    required this.showOverlay,
    required this.trackingActive,
    required this.onToggleOverlay,
    required this.onToggleTracking,
    required this.backend,
    required this.onSelectBackend,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: onToggleOverlay,
                  icon: Icon(
                    showOverlay ? Icons.visibility_off : Icons.visibility,
                  ),
                  label: Text(
                    showOverlay ? 'Hide Bounding Box' : 'Show Bounding Box',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Model: ${backend.label}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: onToggleTracking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: trackingActive ? Colors.red[600] : Colors.green[600],
                ),
                icon: Icon(trackingActive ? Icons.stop : Icons.play_arrow),
                label: Text(trackingActive ? 'Stop Tracking' : 'Start Tracking'),
              ),
              TextButton(
                onPressed: onSelectBackend,
                child: const Text('Change Model'),
              ),
            ],
          )
        ],
      ),
    );
  }
}
