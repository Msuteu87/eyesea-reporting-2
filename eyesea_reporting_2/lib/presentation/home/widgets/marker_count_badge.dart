import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/reports_map_provider.dart';

/// Badge showing total marker count and pending count.
/// Displays in top right corner of the map.
class MarkerCountBadge extends StatelessWidget {
  const MarkerCountBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportsMapProvider>(
      builder: (context, provider, _) {
        if (provider.markers.isEmpty) return const SizedBox.shrink();

        final pendingCount = provider.markers.where((m) => m.isPending).length;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on,
                size: 16,
                color: AppColors.oceanBlue,
              ),
              const SizedBox(width: 4),
              Text(
                '${provider.markers.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (pendingCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.amberGlow.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$pendingCount pending',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.amberGlow,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
