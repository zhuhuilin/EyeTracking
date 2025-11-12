import 'package:flutter/material.dart';
import '../models/model_info.dart';

/// Card widget that displays model information including name, size, performance
/// ratings, and action buttons.
class ModelCard extends StatelessWidget {
  final ModelInfo model;
  final bool isDefault;
  final VoidCallback? onSetDefault;
  final VoidCallback? onDetails;
  final VoidCallback? onTest;

  const ModelCard({
    super.key,
    required this.model,
    this.isDefault = false,
    this.onSetDefault,
    this.onDetails,
    this.onTest,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with name and default badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    model.fullDisplayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Default',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Performance metrics
            Row(
              children: [
                _buildMetric(
                  'Speed',
                  model.speedRating,
                  Icons.speed,
                  Colors.green,
                ),
                const SizedBox(width: 24),
                _buildMetric(
                  'Accuracy',
                  model.accuracyRating,
                  Icons.verified,
                  Colors.blue,
                ),
                const SizedBox(width: 24),
                _buildSizeInfo(),
              ],
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              model.performanceDescription,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),

            // Status and backend info
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChip(
                  icon: Icons.memory,
                  label: model.type.name.toUpperCase(),
                  color: Colors.purple,
                ),
                if (model.variant != ModelVariant.standard)
                  _buildChip(
                    icon: Icons.tune,
                    label: 'Variant: ${model.variantDisplayName}',
                    color: Colors.orange,
                  ),
                _buildChip(
                  icon: Icons.check_circle,
                  label: 'Bundled',
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                if (!isDefault && onSetDefault != null)
                  OutlinedButton.icon(
                    onPressed: onSetDefault,
                    icon: const Icon(Icons.star_outline, size: 18),
                    label: const Text('Set Default'),
                  ),
                if (!isDefault && onSetDefault != null)
                  const SizedBox(width: 8),
                if (onTest != null)
                  OutlinedButton.icon(
                    onPressed: onTest,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Test'),
                  ),
                if (onTest != null)
                  const SizedBox(width: 8),
                if (onDetails != null)
                  TextButton.icon(
                    onPressed: onDetails,
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('Details'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, double value, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        _buildRatingBar(value, color),
      ],
    );
  }

  Widget _buildRatingBar(double value, Color color) {
    final filledBars = (value * 5).round();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Container(
          width: 8,
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: index < filledBars ? color : Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  Widget _buildSizeInfo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.storage, size: 18, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          'Size: ${model.sizeString}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
      backgroundColor: color.withOpacity(0.1),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
