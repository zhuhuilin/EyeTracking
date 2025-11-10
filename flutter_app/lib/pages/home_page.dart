import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_state.dart';
import '../widgets/circle_test_widget.dart';
import '../widgets/test_configuration_dialog.dart';
import '../widgets/camera_selection_dialog.dart';
import '../widgets/camera_preview_widget.dart';
import 'calibration_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EyeBall Tracking'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: _showCameraSelection,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeSection(appState),
                const SizedBox(height: 24),
                const CameraPreviewWidget(),
                const SizedBox(height: 24),
                _buildTestControls(appState),
                const SizedBox(height: 24),
                if (appState.isTracking) _buildTrackingSection(appState),
                if (!appState.isTracking) _buildHistorySection(),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Consumer<AppState>(
        builder: (context, appState, child) {
          return FloatingActionButton.extended(
            onPressed: appState.isTracking ? null : _startTest,
            label: const Text('Start Test'),
            icon: const Icon(Icons.play_arrow),
            backgroundColor: appState.isTracking ? Colors.grey : Colors.blue,
          );
        },
      ),
    );
  }

  Widget _buildWelcomeSection(AppState appState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(
              Icons.face_retouching_natural,
              size: 48,
              color: Colors.blue,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${appState.currentUser?.email ?? 'User'}!',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ready to test your eye tracking accuracy?',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestControls(AppState appState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Test Configuration',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showTestConfiguration,
                    icon: const Icon(Icons.timer),
                    label: const Text('Configure Test'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showCalibration,
                    icon: const Icon(Icons.adjust),
                    label: const Text('Calibrate'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingSection(AppState appState) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Test in Progress',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.green),
                ),
                ElevatedButton(
                  onPressed: _stopTest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Stop Test'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 400,
          child: CircleTestWidget(onTestComplete: _onTestComplete),
        ),
      ],
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Tests', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        SizedBox(
          height: 400,
          child: ListView(
            children: [
              _buildTestResultItem('Test 1', '85% accuracy', '2 minutes ago'),
              _buildTestResultItem('Test 2', '72% accuracy', '1 hour ago'),
              _buildTestResultItem('Test 3', '91% accuracy', 'Yesterday'),
              _buildTestResultItem('Test 4', '68% accuracy', '2 days ago'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTestResultItem(String title, String result, String time) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.visibility, color: Colors.blue),
        title: Text(title),
        subtitle: Text(result),
        trailing: Text(
          time,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
        onTap: () {
          // Show test details
        },
      ),
    );
  }

  void _startTest() {
    showDialog(
      context: context,
      builder: (context) => TestConfigurationDialog(
        onConfigurationSelected: (config) {
          Provider.of<AppState>(
            context,
            listen: false,
          ).startTestSession(config);
        },
      ),
    );
  }

  void _stopTest() {
    Provider.of<AppState>(context, listen: false).stopTestSession();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test stopped'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _onTestComplete() {
    // Handle test completion
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test completed successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => Consumer<AppState>(
        builder: (context, appState, child) => AlertDialog(
          title: const Text('Settings'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Storage Settings',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Use Cloud Storage'),
                  subtitle: const Text('Store test data in the cloud'),
                  value: appState.settings.useCloudStorage,
                  onChanged: (value) {
                    appState.updateSettings(
                      appState.settings.copyWith(useCloudStorage: value),
                    );
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Processing Settings',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Enable Analytics'),
                  subtitle: const Text('Send anonymous usage data'),
                  value: appState.settings.enableAnalytics,
                  onChanged: (value) {
                    appState.updateSettings(
                      appState.settings.copyWith(enableAnalytics: value),
                    );
                  },
                ),
                const SizedBox(height: 8),
                const Text('Processing Quality'),
                Slider(
                  value: appState.settings.processingQuality,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  label:
                      '${(appState.settings.processingQuality * 100).round()}%',
                  onChanged: (value) {
                    appState.updateSettings(
                      appState.settings.copyWith(processingQuality: value),
                    );
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'About',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'EyeBall Tracking v1.0.0\nReal-time eye tracking application',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTestConfiguration() {
    _startTest();
  }

  void _showCalibration() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const CalibrationPage()),
    );
  }

  void _showCameraSelection() {
    showDialog(
      context: context,
      builder: (context) => const CameraSelectionDialog(),
    );
  }

  void _logout() {
    Provider.of<AppState>(context, listen: false).setUser(null);
  }
}
