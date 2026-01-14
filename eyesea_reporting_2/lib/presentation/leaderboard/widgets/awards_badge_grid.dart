import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/badge.dart';
import 'awards_badge_card.dart';

/// Grid of badges for the awards section.
class AwardsBadgeGrid extends StatelessWidget {
  final List<BadgeEntity> earnedBadges;
  final List<BadgeEntity> lockedBadges;
  final ValueChanged<BadgeEntity>? onBadgeTap;

  const AwardsBadgeGrid({
    super.key,
    required this.earnedBadges,
    required this.lockedBadges,
    this.onBadgeTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Earned badges section
        if (earnedBadges.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            title: 'Earned Badges',
            count: earnedBadges.length,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildBadgeGrid(earnedBadges),
          const SizedBox(height: 24),
        ],

        // Locked badges section
        if (lockedBadges.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            title: 'Locked Badges',
            count: lockedBadges.length,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildBadgeGrid(lockedBadges),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required int count,
    required bool isDark,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.darkGunmetal,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.electricNavy.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.electricNavy,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeGrid(List<BadgeEntity> badges) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final badge = badges[index];
        return AwardsBadgeCard(
          badge: badge,
          onTap: onBadgeTap != null ? () => onBadgeTap!(badge) : null,
        );
      },
    );
  }
}
