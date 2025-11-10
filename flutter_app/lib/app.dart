import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/app_state.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/admin_dashboard.dart';

class EyeBallTrackingApp extends StatelessWidget {
  const EyeBallTrackingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EyeBall Tracking',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Consumer<AppState>(
        builder: (context, appState, child) {
          if (appState.currentUser == null) {
            return const LoginPage();
          } else if (appState.currentUser?.role == UserRole.admin) {
            return const AdminDashboard();
          } else {
            return const HomePage();
          }
        },
      ),
      routes: {
        '/home': (context) => const HomePage(),
        '/login': (context) => const LoginPage(),
        '/admin': (context) => const AdminDashboard(),
      },
    );
  }
}
