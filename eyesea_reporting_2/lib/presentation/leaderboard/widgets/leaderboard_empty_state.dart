import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';

/// Empty state widget for leaderboard when no data is available.
class LeaderboardEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  const LeaderboardEmptyState({
    super.key,
    this.icon = LucideIcons.trophy,
    required this.title,
    required this.subtitle,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.electricNavy.withValues(alpha: 0.1),
              ),
              child: Icon(
                icon,
                size: 36,
                color: AppColors.electricNavy,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.darkGunmetal,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : AppColors.coolGray,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(LucideIcons.refreshCw, size: 16),
                label: const Text('Try Again'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.electricNavy,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
