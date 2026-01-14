import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/report.dart';
import '../../providers/reports_map_provider.dart';
import 'recovery_confirmation_dialog.dart';

/// Premium report detail card with hero image layout.
/// Displays at the bottom of the map when a marker is tapped.
class ReportDetailCard extends StatelessWidget {
  final MapMarkerData marker;
  final VoidCallback? onClose;
  final Future<void> Function(String reportId)? onMarkRecovered;

  const ReportDetailCard({
    super.key,
    required this.marker,
    this.onClose,
    this.onMarkRecovered,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hero Image Section
          _buildHeroImage(context, isDark),

          // Content Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Type + Close button
                _buildHeader(context, isDark),
                const SizedBox(height: 8),

                // Location
                _buildLocation(context, isDark),
                const SizedBox(height: 12),

                // Item breakdown chips + weight
                _buildItemBreakdown(context, isDark),
                const SizedBox(height: 12),

                // Severity bar
                _buildSeverityBar(context, isDark),
                const SizedBox(height: 16),

                // Footer: Timestamp + Action button
                _buildFooter(context, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Hero image with status badge overlay
  Widget _buildHeroImage(BuildContext context, bool isDark) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image or placeholder
          if (marker.imageUrl != null && marker.imageUrl!.isNotEmpty)
            Image.network(
              marker.imageUrl!,
              fit: BoxFit.cover,
              cacheWidth: 800, // Limit decoded image size for performance
              errorBuilder: (_, __, ___) => _buildImagePlaceholder(isDark),
            )
          else
            _buildImagePlaceholder(isDark),

          // Status badge overlay (top-right)
          Positioned(
            top: 12,
            right: 12,
            child: _buildStatusBadge(),
          ),
        ],
      ),
    );
  }

  /// Placeholder when no image available
  Widget _buildImagePlaceholder(bool isDark) {
    return Container(
      color: isDark ? Colors.grey[800] : Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.image,
            size: 48,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            'No photo',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  /// Status badge (Active, Pending, Recovered)
  Widget _buildStatusBadge() {
    Color bgColor;
    Color textColor;
    IconData icon;
    String label;

    if (marker.status == ReportStatus.resolved) {
      bgColor = AppColors.emerald.withValues(alpha: 0.9);
      textColor = Colors.white;
      icon = LucideIcons.checkCircle2;
      label = 'Recovered';
    } else if (marker.isPending) {
      bgColor = AppColors.amberGlow.withValues(alpha: 0.9);
      textColor = Colors.white;
      icon = LucideIcons.clock;
      label = 'Pending Sync';
    } else {
      bgColor = AppColors.electricNavy.withValues(alpha: 0.9);
      textColor = Colors.white;
      icon = LucideIcons.alertCircle;
      label = 'Active';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Header with pollution type and close button
  Widget _buildHeader(BuildContext context, bool isDark) {
    final typeIcon = _getPollutionIcon(marker.pollutionType);
    final typeName = _getPollutionName(marker.pollutionType);

    return Row(
      children: [
        Icon(
          typeIcon,
          size: 22,
          color: AppColors.electricNavy,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            typeName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        if (onClose != null)
          GestureDetector(
            onTap: onClose,
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(
                LucideIcons.x,
                size: 22,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
      ],
    );
  }

  /// Location display (City, Country)
  Widget _buildLocation(BuildContext context, bool isDark) {
    String locationText;
    if (marker.city != null && marker.country != null) {
      locationText = '${marker.city}, ${marker.country}';
    } else if (marker.city != null) {
      locationText = marker.city!;
    } else if (marker.country != null) {
      locationText = marker.country!;
    } else {
      locationText = 'Location unavailable';
    }

    return Row(
      children: [
        Icon(
          LucideIcons.mapPin,
          size: 14,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            locationText,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Item breakdown chips with weight
  Widget _buildItemBreakdown(BuildContext context, bool isDark) {
    final chips = <Widget>[];

    // Add pollution type chips
    if (marker.pollutionCounts.isNotEmpty) {
      for (final entry in marker.pollutionCounts.entries) {
        if (entry.value > 0) {
          chips.add(_buildTypeChip(entry.key, entry.value, isDark));
        }
      }
    }

    // Add weight chip at the end
    if (marker.totalWeightKg != null && marker.totalWeightKg! > 0) {
      chips.add(_buildWeightChip(marker.totalWeightKg!, isDark));
    }

    if (chips.isEmpty) {
      // Fallback: show total items if no breakdown
      if (marker.totalItems > 0) {
        chips.add(_buildGenericItemChip(marker.totalItems, isDark));
      }
    }

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: chips,
    );
  }

  /// Individual pollution type chip
  Widget _buildTypeChip(PollutionType type, int count, bool isDark) {
    final icon = _getPollutionIcon(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.electricNavy.withValues(alpha: isDark ? 0.15 : 0.1),
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

  /// Weight display chip
  Widget _buildWeightChip(double weightKg, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.scale,
            size: 14,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
          const SizedBox(width: 4),
          Text(
            '~${weightKg.toStringAsFixed(1)} kg',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  /// Generic item count chip (fallback)
  Widget _buildGenericItemChip(int count, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.electricNavy.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.hash,
            size: 14,
            color: AppColors.electricNavy,
          ),
          const SizedBox(width: 4),
          Text(
            '$count items',
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

  /// Severity bar with label
  Widget _buildSeverityBar(BuildContext context, bool isDark) {
    final severityColor = _getSeverityColor(marker.severity);
    final severityLabel = _getSeverityLabel(marker.severity);

    return Row(
      children: [
        // Severity segments
        Expanded(
          child: Row(
            children: List.generate(5, (i) {
              final isActive = i < marker.severity;
              return Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(right: i < 4 ? 3 : 0),
                  decoration: BoxDecoration(
                    color: isActive
                        ? severityColor
                        : (isDark ? Colors.grey[700] : Colors.grey[300]),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 12),
        // Severity label
        Text(
          severityLabel,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: severityColor,
          ),
        ),
      ],
    );
  }

  /// Footer with timestamp and action button
  Widget _buildFooter(BuildContext context, bool isDark) {
    final showRecoveryButton = marker.status != ReportStatus.resolved &&
        !marker.isPending &&
        onMarkRecovered != null;

    return Row(
      children: [
        // Timestamp
        Icon(
          LucideIcons.calendar,
          size: 14,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        const SizedBox(width: 6),
        Text(
          _formatDate(marker.createdAt),
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const Spacer(),

        // Mark as Cleaned button (only if not resolved and not pending sync)
        if (showRecoveryButton)
          TextButton.icon(
            onPressed: () => _handleRecovery(context),
            icon: const Icon(LucideIcons.checkCircle2, size: 16),
            label: const Text('Mark as Recovered'),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
      ],
    );
  }

  // Helper methods

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
    if (severity <= 2) return AppColors.emerald;
    if (severity <= 3) return Colors.orange;
    return AppColors.punchRed;
  }

  String _getSeverityLabel(int severity) {
    if (severity <= 2) return 'Low';
    if (severity <= 3) return 'Moderate';
    return 'Severe';
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
