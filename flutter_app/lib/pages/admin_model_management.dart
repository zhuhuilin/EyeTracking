import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/model_registry.dart';
import '../services/camera_service.dart';
import '../models/model_info.dart';
import '../widgets/model_card.dart';

/// Admin page for managing face detection models including viewing, testing,
/// and setting default models.
class AdminModelManagement extends StatefulWidget {
  const AdminModelManagement({super.key});

  @override
  State<AdminModelManagement> createState() => _AdminModelManagementState();
}

class _AdminModelManagementState extends State<AdminModelManagement> {
  String? _defaultModelId;
  ModelType? _filterType;

  @override
  void initState() {
    super.initState();
    _loadDefaultModel();
  }

  Future<void> _loadDefaultModel() async {
    final registry = ModelRegistry.instance;
    final defaultModel = registry.getDefaultModel();
    if (defaultModel != null && mounted) {
      setState(() {
        _defaultModelId = defaultModel.id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final registry = ModelRegistry.instance;
    final allModels = registry.getAllModels();

    // Filter models by type if selected
    final filteredModels = _filterType != null
        ? allModels.where((m) => m.type == _filterType).toList()
        : allModels;

    // Sort by default first, then by name
    filteredModels.sort((a, b) {
      if (a.id == _defaultModelId) return -1;
      if (b.id == _defaultModelId) return 1;
      return a.fullDisplayName.compareTo(b.fullDisplayName);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Model Management'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          // Filter dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButton<ModelType?>(
              value: _filterType,
              icon: const Icon(Icons.filter_list, color: Colors.white),
              underline: Container(),
              dropdownColor: Colors.blue[600],
              style: const TextStyle(color: Colors.white),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All Models', style: TextStyle(color: Colors.white)),
                ),
                ...ModelType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(
                      type.name.toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }),
              ],
              onChanged: (type) {
                setState(() {
                  _filterType = type;
                });
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats summary
          _buildStatsCard(allModels),

          // Model list
          Expanded(
            child: filteredModels.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: filteredModels.length,
                    itemBuilder: (context, index) {
                      final model = filteredModels[index];
                      return ModelCard(
                        model: model,
                        isDefault: model.id == _defaultModelId,
                        onSetDefault: () => _setDefaultModel(model),
                        onDetails: () => _showModelDetails(model),
                        onTest: () => _testModel(model),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(List<ModelInfo> models) {
    final yoloCount = models.where((m) => m.type == ModelType.yolo).length;
    final yuNetCount = models.where((m) => m.type == ModelType.yunet).length;
    final haarCount = models.where((m) => m.type == ModelType.haar).length;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              'Total Models',
              '${models.length}',
              Icons.memory,
              Colors.blue,
            ),
            _buildStatItem(
              'YOLO',
              '$yoloCount',
              Icons.bolt,
              Colors.purple,
            ),
            _buildStatItem(
              'YuNet',
              '$yuNetCount',
              Icons.face,
              Colors.green,
            ),
            _buildStatItem(
              'Haar Cascade',
              '$haarCount',
              Icons.grid_on,
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No models found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try changing the filter',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setDefaultModel(ModelInfo model) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Default Model'),
        content: Text(
          'Set ${model.fullDisplayName} as the default model?\n\n'
          'This will be used for all new calibrations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Set Default'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _defaultModelId = model.id;
      });

      // Also set it in CameraService
      final cameraService = Provider.of<CameraService>(context, listen: false);
      await cameraService.setModel(model.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${model.displayName} set as default'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _showModelDetails(ModelInfo model) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(model.fullDisplayName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Model ID', model.id),
              _buildDetailRow('Type', model.type.name.toUpperCase()),
              if (model.variant != ModelVariant.standard)
                _buildDetailRow('Variant', model.variantDisplayName),
              _buildDetailRow('Size', model.sizeString),
              _buildDetailRow(
                'Speed',
                '${(model.speedRating * 100).toStringAsFixed(0)}%',
              ),
              _buildDetailRow(
                'Accuracy',
                '${(model.accuracyRating * 100).toStringAsFixed(0)}%',
              ),
              _buildDetailRow('File Path', model.filePath),
              _buildDetailRow('Format', model.format.name.toUpperCase()),
              _buildDetailRow('Platform', model.platform.name),
              _buildDetailRow('Bundled', model.bundled ? 'Yes' : 'No'),
              const SizedBox(height: 16),
              const Text(
                'Performance',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(model.performanceDescription),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testModel(ModelInfo model) async {
    final cameraService = Provider.of<CameraService>(context, listen: false);

    // Show dialog with info
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Test ${model.displayName}'),
        content: const Text(
          'To test this model, go to the Calibration page and select it '
          'from the model selector. The camera preview will show real-time '
          'detection using this model.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await cameraService.setModel(model.id);
              if (context.mounted) {
                Navigator.pop(context); // Go back to previous page
              }
            },
            child: const Text('Go to Calibration'),
          ),
        ],
      ),
    );
  }
}
