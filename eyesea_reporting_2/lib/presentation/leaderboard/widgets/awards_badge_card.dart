import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/badge.dart';

/// Individual badge card for the awards grid.
class AwardsBadgeCard extends StatelessWidget {
  final BadgeEntity badge;
  final VoidCallback? onTap;

  const AwardsBadgeCard({
    super.key,
    required this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with background
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: badge.isEarned
                    ? badge.color.withValues(alpha: 0.15)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.withValues(alpha: 0.1)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    _getIconData(badge.icon),
                    size: 28,
                    color: badge.isEarned
                        ? badge.color
                        : (isDark ? Colors.white38 : Colors.grey),
                  ),
                  if (!badge.isEarned)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? AppColors.darkSurface : Colors.white,
                        ),
                        child: Icon(
                          LucideIcons.lock,
                          size: 10,
                          color: isDark ? Colors.white38 : Colors.grey,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Badge name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                badge.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: badge.isEarned
                      ? (isDark ? Colors.white : AppColors.darkGunmetal)
                      : (isDark ? Colors.white38 : Colors.grey),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    return switch (iconName) {
      'trophy' => LucideIcons.trophy,
      'award' => LucideIcons.award,
      'crown' => LucideIcons.crown,
      'shield' => LucideIcons.shield,
      'star' => LucideIcons.star,
      'flame' => LucideIcons.flame,
      'zap' => LucideIcons.zap,
      'heart' => LucideIcons.heart,
      'users' => LucideIcons.users,
      'target' => LucideIcons.target,
      'medal' => LucideIcons.medal,
      'flag' => LucideIcons.flag,
      'calendar' => LucideIcons.calendar,
      'compass' => LucideIcons.compass,
      'anchor' => LucideIcons.anchor,
      _ => LucideIcons.award,
    };
  }
}
