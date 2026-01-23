import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/leaderboard_data_source.dart';
import '../../../domain/entities/leaderboard_entry.dart';

/// Individual leaderboard list item.
class LeaderboardListItem extends StatelessWidget {
  final LeaderboardEntry entry;
  final LeaderboardCategory category;
  final bool isCurrentUser;

  const LeaderboardListItem({
    super.key,
    required this.entry,
    required this.category,
    this.isCurrentUser = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppColors.electricNavy.withValues(alpha: 0.1)
            : (isDark ? AppColors.darkSurface : AppColors.pureWhite),
        borderRadius: BorderRadius.circular(12),
        border: isCurrentUser
            ? Border.all(color: AppColors.electricNavy, width: 2)
            : null,
        boxShadow: [
          if (!isCurrentUser)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Rank badge
            _buildRankBadge(isDark),
            const SizedBox(width: 12),

            // Avatar/Logo
            _buildAvatar(isDark),
            const SizedBox(width: 12),

            // Name and subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.darkGunmetal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getSubtitle(),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : AppColors.coolGray,
                    ),
                  ),
                ],
              ),
            ),

            // Credits badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.electricNavy.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${entry.totalXp} Credits',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.electricNavy,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankBadge(bool isDark) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.1),
      ),
      child: Center(
        child: Text(
          '${entry.rank}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : AppColors.coolGray,
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(bool isDark) {
    final url = entry.avatarUrl ?? entry.logoUrl;
    final hasImage = url != null && url.isNotEmpty;

    return CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.electricNavy.withValues(alpha: 0.1),
      backgroundImage: hasImage ? NetworkImage(url) : null,
      child: hasImage ? null : _buildAvatarFallback(),
    );
  }

  Widget _buildAvatarFallback() {
    final IconData icon = switch (category) {
      LeaderboardCategory.users => LucideIcons.user,
      LeaderboardCategory.organizations => LucideIcons.building2,
      LeaderboardCategory.vessels => LucideIcons.ship,
    };

    return Icon(icon, color: AppColors.electricNavy, size: 18);
  }

  String _getSubtitle() {
    return switch (category) {
      LeaderboardCategory.users => '${entry.reportsCount} reports',
      LeaderboardCategory.organizations =>
        '${entry.reportsCount} reports${entry.subtitle != null ? ' • ${entry.subtitle}' : ''}',
      LeaderboardCategory.vessels =>
        '${entry.reportsCount} reports${entry.subtitle != null ? ' • ${entry.subtitle}' : ''}',
    };
  }
}
