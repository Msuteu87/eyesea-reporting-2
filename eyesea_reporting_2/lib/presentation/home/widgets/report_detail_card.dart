import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/report.dart';
import '../../providers/reports_map_provider.dart';
import 'recovery_confirmation_dialog.dart';

/// Card widget showing report details at the bottom of the map.
/// Displays thumbnail, pollution type, severity, city/country, and date.
class ReportDetailCard extends StatelessWidget {
  final MapMarkerData marker;
  final String? imageUrl;
  final VoidCallback? onTap;
  final VoidCallback? onClose;
  final Future<void> Function(String reportId)? onMarkRecovered;

  const ReportDetailCard({
    super.key,
    required this.marker,
    this.imageUrl,
    this.onTap,
    this.onClose,
    this.onMarkRecovered,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeIcon = _getPollutionIcon(marker.pollutionType);
    final typeName = _getPollutionName(marker.pollutionType);
    final severityColor = _getSeverityColor(marker.severity);

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 80,
                    height: 80,
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    child: imageUrl != null && imageUrl!.isNotEmpty
                        ? Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildPlaceholder(isDark),
                          )
                        : _buildPlaceholder(isDark),
                  ),
                ),
                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Type + Status
                      Row(
                        children: [
                          Icon(
                            typeIcon,
                            size: 18,
                            color: AppColors.electricNavy,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              typeName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Status badge
                          if (marker.status == ReportStatus.resolved)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Recovered',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                            )
                          else if (marker.isPending)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.amberGlow.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Pending',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.amberGlow,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Weight & Count row
                      Row(
                        children: [
                          if (marker.totalWeightKg != null) ...[
                            Icon(
                              LucideIcons.scale,
                              size: 12,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${marker.totalWeightKg!.toStringAsFixed(1)} kg',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.grey[300]
                                    : Colors.grey[700],
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (marker.totalItems > 0) ...[
                            Icon(
                              LucideIcons.hash,
                              size: 12,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${marker.totalItems} items',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.grey[300]
                                    : Colors.grey[700],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (marker.totalWeightKg != null || marker.totalItems > 0)
                        const SizedBox(height: 6),

                      // Pollution type icons row
                      if (marker.pollutionCounts.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: marker.pollutionCounts.entries
                              .where((e) => e.value > 0)
                              .map(
                                  (e) => _buildTypeChip(e.key, e.value, isDark))
                              .toList(),
                        )
                      else
                        // Severity bar (fallback when no pollution counts)
                        Row(
                          children: [
                            Text(
                              'Severity: ',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                            ...List.generate(5, (i) {
                              return Container(
                                width: 16,
                                height: 6,
                                margin: const EdgeInsets.only(right: 2),
                                decoration: BoxDecoration(
                                  color: i < marker.severity
                                      ? severityColor
                                      : (isDark
                                          ? Colors.grey[700]
                                          : Colors.grey[300]),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            }),
                          ],
                        ),
                      const SizedBox(height: 6),

                      // Date
                      Row(
                        children: [
                          Icon(
                            LucideIcons.calendar,
                            size: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(marker.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Action buttons column
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Close button
                    if (onClose != null)
                      IconButton(
                        onPressed: onClose,
                        icon: Icon(
                          LucideIcons.x,
                          size: 20,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    // Recovery button (only show if not resolved and not pending sync)
                    if (marker.status != ReportStatus.resolved &&
                        !marker.isPending &&
                        onMarkRecovered != null)
                      _RecoveryButton(
                        onPressed: () => _handleRecovery(context),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Center(
      child: Icon(
        LucideIcons.image,
        size: 32,
        color: isDark ? Colors.grey[600] : Colors.grey[400],
      ),
    );
  }

  Widget _buildTypeChip(PollutionType type, int count, bool isDark) {
    final icon = _getPollutionIcon(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.electricNavy.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: AppColors.electricNavy,
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.electricNavy,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPollutionIcon(PollutionType type) {
    switch (type) {
      case PollutionType.plastic:
        return LucideIcons.milk;
      case PollutionType.oil:
        return LucideIcons.droplet;
      case PollutionType.debris:
        return LucideIcons.trash2;
      case PollutionType.sewage:
        return LucideIcons.droplets;
      case PollutionType.fishingGear:
        return LucideIcons.anchor;
      case PollutionType.container:
        return LucideIcons.box;
      case PollutionType.other:
        return LucideIcons.helpCircle;
    }
  }

  String _getPollutionName(PollutionType type) {
    switch (type) {
      case PollutionType.plastic:
        return 'Plastic Waste';
      case PollutionType.oil:
        return 'Oil Spill';
      case PollutionType.debris:
        return 'Marine Debris';
      case PollutionType.sewage:
        return 'Sewage';
      case PollutionType.fishingGear:
        return 'Fishing Gear';
      case PollutionType.container:
        return 'Container';
      case PollutionType.other:
        return 'Other Pollution';
    }
  }

  Color _getSeverityColor(int severity) {
    if (severity <= 2) return Colors.green;
    if (severity <= 3) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${date.day}/${date.month}/${date.year}';
  }

  /// Handle recovery button tap - show confirmation dialog
  Future<void> _handleRecovery(BuildContext context) async {
    final confirmed = await RecoveryConfirmationDialog.show(context);
    if (confirmed && onMarkRecovered != null) {
      await onMarkRecovered!(marker.id);
    }
  }
}

/// Circular green checkmark button for marking reports as recovered
class _RecoveryButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _RecoveryButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.emerald.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        icon: const Icon(
          LucideIcons.checkCircle2,
          size: 22,
          color: AppColors.emerald,
        ),
        tooltip: 'Mark as Recovered',
      ),
    );
  }
}
