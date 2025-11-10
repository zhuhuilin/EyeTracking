import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'models/app_state.dart';
import 'services/camera_service.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AppState()),
        Provider(create: (context) => CameraService()),
      ],
      child: const EyeBallTrackingApp(),
    ),
  );
}
