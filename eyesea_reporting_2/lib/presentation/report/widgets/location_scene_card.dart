import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';

/// A compact card widget displaying location and scene info in a single row.
class LocationSceneCard extends StatelessWidget {
  final String? city;
  final String? country;
  final double? latitude;
  final double? longitude;
  final List<String> sceneLabels;
  final bool isLoadingLocation;
  final bool isLoadingScene;
  final VoidCallback? onEditLocation;

  const LocationSceneCard({
    super.key,
    this.city,
    this.country,
    this.latitude,
    this.longitude,
    this.sceneLabels = const [],
    this.isLoadingLocation = false,
    this.isLoadingScene = false,
    this.onEditLocation,
  });

  String get _locationDisplay {
    if (city != null && country != null) {
      // Compact: "San Francisco, US" instead of full country name
      return '$city, $country';
    } else if (country != null) {
      return country!;
    } else if (city != null) {
      return city!;
    } else if (latitude != null && longitude != null) {
      return '${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}';
    } else {
      return 'Unknown';
    }
  }

  bool get _hasLocation => latitude != null && longitude != null;

  String? get _topScene => sceneLabels.isNotEmpty ? sceneLabels.first : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          // Location icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _hasLocation
                  ? AppColors.successGreen.withValues(alpha: 0.12)
                  : Colors.orange.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _hasLocation ? LucideIcons.mapPin : LucideIcons.loader2,
              size: 16,
              color: _hasLocation ? AppColors.successGreen : Colors.orange,
            ),
          ),
          const SizedBox(width: 10),

          // Location text
          Expanded(
            child: isLoadingLocation
                ? Text(
                    'Detecting...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.white54 : Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  )
                : Text(
                    _locationDisplay,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
          ),

          // Scene label (if available)
          if (_topScene != null && !isLoadingScene) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.oceanBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getSceneIcon(_topScene!.toLowerCase()),
                    size: 12,
                    color: AppColors.oceanBlue,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _topScene!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.oceanBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isLoadingScene) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.oceanBlue.withValues(alpha: 0.5),
              ),
            ),
          ],

          // Edit button
          if (_hasLocation && onEditLocation != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onEditLocation,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.pencil,
                  size: 14,
                  color: isDark ? Colors.white54 : Colors.grey[500],
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2);
  }

  IconData _getSceneIcon(String label) {
    if (label.contains('beach') ||
        label.contains('coast') ||
        label.contains('shore')) {
      return LucideIcons.palmtree;
    }
    if (label.contains('water') ||
        label.contains('ocean') ||
        label.contains('sea') ||
        label.contains('river')) {
      return LucideIcons.waves;
    }
    if (label.contains('rock') || label.contains('mountain')) {
      return LucideIcons.mountain;
    }
    if (label.contains('forest') ||
        label.contains('tree') ||
        label.contains('nature')) {
      return LucideIcons.treePine;
    }
    if (label.contains('urban') ||
        label.contains('city') ||
        label.contains('building')) {
      return LucideIcons.building2;
    }
    if (label.contains('road') || label.contains('street')) {
      return LucideIcons.car;
    }
    return LucideIcons.mapPin;
  }
}
