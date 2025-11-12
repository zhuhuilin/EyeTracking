import 'package:flutter/material.dart';
import '../models/model_info.dart';
import '../services/model_registry.dart';

/// Dialog for selecting AI detection model
/// Shows available models with performance ratings, download status, and metadata
class ModelSelectionDialog extends StatefulWidget {
  final String? currentModelId;
  final SupportedPlatform? platform;

  const ModelSelectionDialog({
    super.key,
    this.currentModelId,
    this.platform,
  });

  @override
  State<ModelSelectionDialog> createState() => _ModelSelectionDialogState();
}

class _ModelSelectionDialogState extends State<ModelSelectionDialog> {
  final ModelRegistry _registry = ModelRegistry.instance;
  List<ModelInfo> _models = [];
  String? _selectedModelId;
  String _filterType = 'all';
  bool _showOnlyAvailable = true;

  @override
  void initState() {
    super.initState();
    _selectedModelId = widget.currentModelId;
    _loadModels();
  }

  void _loadModels() {
    setState(() {
      List<ModelInfo> models = _registry.getModelsForPlatform(widget.platform);

      // Apply type filter
      if (_filterType != 'all') {
        final type = ModelType.values.firstWhere((t) => t.name == _filterType);
        models = models.where((m) => m.type == type).toList();
      }

      // Apply availability filter
      if (_showOnlyAvailable) {
        models = models.where((m) => m.isAvailable).toList();
      }

      // Sort by performance (balanced score)
      models.sort((a, b) {
        final scoreA = (a.speedRating + a.accuracyRating) / 2;
        final scoreB = (b.speedRating + b.accuracyRating) / 2;
        return scoreB.compareTo(scoreA);
      });

      _models = models;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 600,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.memory, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Select Detection Model',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Filters
            _buildFilters(),
            const SizedBox(height: 16),

            // Model count
            Text(
              '${_models.length} model${_models.length != 1 ? 's' : ''} available',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),

            // Model list
            Expanded(
              child: _models.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: _models.length,
                      itemBuilder: (context, index) {
                        return _buildModelCard(_models[index]);
                      },
                    ),
            ),

            const SizedBox(height: 16),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _selectedModelId != null
                      ? () => Navigator.pop(context, _selectedModelId)
                      : null,
                  child: const Text('Select Model'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        // Type filter
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _filterType,
            decoration: const InputDecoration(
              labelText: 'Model Type',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Types')),
              DropdownMenuItem(value: 'yolo', child: Text('YOLO')),
              DropdownMenuItem(value: 'yunet', child: Text('YuNet')),
              DropdownMenuItem(value: 'haar', child: Text('Haar Cascade')),
              DropdownMenuItem(value: 'mediaPipe', child: Text('MediaPipe')),
            ],
            onChanged: (value) {
              setState(() {
                _filterType = value ?? 'all';
                _loadModels();
              });
            },
          ),
        ),
        const SizedBox(width: 16),

        // Availability toggle
        Expanded(
          child: CheckboxListTile(
            value: _showOnlyAvailable,
            onChanged: (value) {
              setState(() {
                _showOnlyAvailable = value ?? true;
                _loadModels();
              });
            },
            title: const Text('Show only available'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
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
            _showOnlyAvailable
                ? 'Try disabling "Show only available" filter'
                : 'No models match your criteria',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelCard(ModelInfo model) {
    final isSelected = _selectedModelId == model.id;
    final isCurrentModel = widget.currentModelId == model.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: model.isAvailable
            ? () {
                setState(() {
                  _selectedModelId = model.id;
                });
              }
            : () => _showDownloadPrompt(model),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Model name and type
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              model.fullDisplayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isCurrentModel) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'CURRENT',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${model.type.name.toUpperCase()} • ${model.format.name.toUpperCase()} • ${model.sizeString}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Status badge
                  _buildStatusBadge(model),
                ],
              ),

              const SizedBox(height: 12),

              // Performance indicators
              Row(
                children: [
                  Expanded(
                    child: _buildPerformanceBar(
                      'Accuracy',
                      model.accuracyRating,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildPerformanceBar(
                      'Speed',
                      model.speedRating,
                      Colors.blue,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Performance description
              Text(
                model.performanceDescription,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),

              // Metadata if available
              if (model.metadata.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  model.metadata['description'] ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ModelInfo model) {
    if (model.bundled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 14, color: Colors.green),
            SizedBox(width: 4),
            Text(
              'Bundled',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
      );
    } else if (model.downloaded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_done, size: 14, color: Colors.blue),
            SizedBox(width: 4),
            Text(
              'Downloaded',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_download, size: 14, color: Colors.orange),
            SizedBox(width: 4),
            Text(
              'Download Required',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildPerformanceBar(String label, double rating, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: rating,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(rating * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showDownloadPrompt(ModelInfo model) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The model "${model.fullDisplayName}" is not available on your device.',
            ),
            const SizedBox(height: 16),
            Text(
              'Size: ${model.sizeString}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Would you like to download it now?',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement model download in Phase 7
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Model download feature coming in Phase 7'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }
}
