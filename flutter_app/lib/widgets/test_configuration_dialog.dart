import 'package:flutter/material.dart';
import '../models/app_state.dart';

class TestConfigurationDialog extends StatefulWidget {
  final Function(TestConfiguration) onConfigurationSelected;

  const TestConfigurationDialog({
    super.key,
    required this.onConfigurationSelected,
  });

  @override
  State<TestConfigurationDialog> createState() =>
      _TestConfigurationDialogState();
}

class _TestConfigurationDialogState extends State<TestConfigurationDialog> {
  Duration _selectedDuration = const Duration(minutes: 1);
  TestType _selectedTestType = TestType.random;
  double _circleSize = 50.0;
  int _movementSpeed = 2;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configure Test'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDurationSelector(),
            const SizedBox(height: 16),
            _buildTestTypeSelector(),
            const SizedBox(height: 16),
            _buildCircleSizeSelector(),
            const SizedBox(height: 16),
            _buildMovementSpeedSelector(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _startTest, child: const Text('Start Test')),
      ],
    );
  }

  Widget _buildDurationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Test Duration',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButton<Duration>(
          value: _selectedDuration,
          isExpanded: true,
          items: const [
            DropdownMenuItem(
              value: Duration(minutes: 1),
              child: Text('1 minute'),
            ),
            DropdownMenuItem(
              value: Duration(minutes: 2),
              child: Text('2 minutes'),
            ),
            DropdownMenuItem(
              value: Duration(minutes: 3),
              child: Text('3 minutes'),
            ),
            DropdownMenuItem(
              value: Duration(minutes: 4),
              child: Text('4 minutes'),
            ),
            DropdownMenuItem(
              value: Duration(minutes: 5),
              child: Text('5 minutes'),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _selectedDuration = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildTestTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Test Type', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButton<TestType>(
          value: _selectedTestType,
          isExpanded: true,
          items: const [
            DropdownMenuItem(
              value: TestType.random,
              child: Text('Random Movement'),
            ),
            DropdownMenuItem(
              value: TestType.horizontal,
              child: Text('Horizontal Movement'),
            ),
            DropdownMenuItem(
              value: TestType.vertical,
              child: Text('Vertical Movement'),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _selectedTestType = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildCircleSizeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Circle Size',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Slider(
          value: _circleSize,
          min: 30.0,
          max: 100.0,
          divisions: 7,
          label: '${_circleSize.round()}px',
          onChanged: (value) {
            setState(() {
              _circleSize = value;
            });
          },
        ),
        Text('Size: ${_circleSize.round()} pixels'),
      ],
    );
  }

  Widget _buildMovementSpeedSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Movement Speed',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Slider(
          value: _movementSpeed.toDouble(),
          min: 1.0,
          max: 5.0,
          divisions: 4,
          label: 'Level $_movementSpeed',
          onChanged: (value) {
            setState(() {
              _movementSpeed = value.round();
            });
          },
        ),
        Text('Speed: Level $_movementSpeed'),
      ],
    );
  }

  void _startTest() {
    final config = TestConfiguration(
      duration: _selectedDuration,
      type: _selectedTestType,
      circleSize: _circleSize,
      movementSpeed: _movementSpeed,
    );

    widget.onConfigurationSelected(config);
    Navigator.of(context).pop();
  }
}
