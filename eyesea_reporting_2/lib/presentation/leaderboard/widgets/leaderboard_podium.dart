import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/leaderboard_data_source.dart';
import '../../../domain/entities/leaderboard_entry.dart';

/// Olympic-style podium showing top 3 entries.
/// Layout: #2 (left), #1 (center, elevated), #3 (right)
class LeaderboardPodium extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  final LeaderboardCategory category;

  const LeaderboardPodium({
    super.key,
    required this.entries,
    required this.category,
  });

  static const _goldColor = Color(0xFFFFD700);
  static const _silverColor = Color(0xFFC0C0C0);
  static const _bronzeColor = Color(0xFFCD7F32);

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Arrange as: #2 (left), #1 (center, elevated), #3 (right)
    final first = entries.isNotEmpty ? entries[0] : null;
    final second = entries.length > 1 ? entries[1] : null;
    final third = entries.length > 2 ? entries[2] : null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Second place (left)
          if (second != null)
            Expanded(
              child: _PodiumPlace(
                entry: second,
                rank: 2,
                height: 100,
                color: _silverColor,
                category: category,
                isDark: isDark,
              ),
            )
          else
            const Expanded(child: SizedBox()),

          const SizedBox(width: 8),

          // First place (center, elevated)
          if (first != null)
            Expanded(
              child: _PodiumPlace(
                entry: first,
                rank: 1,
                height: 130,
                color: _goldColor,
                category: category,
                isDark: isDark,
                showCrown: true,
              ),
            )
          else
            const Expanded(child: SizedBox()),

          const SizedBox(width: 8),

          // Third place (right)
          if (third != null)
            Expanded(
              child: _PodiumPlace(
                entry: third,
                rank: 3,
                height: 80,
                color: _bronzeColor,
                category: category,
                isDark: isDark,
              ),
            )
          else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}

class _PodiumPlace extends StatelessWidget {
  final LeaderboardEntry entry;
  final int rank;
  final double height;
  final Color color;
  final LeaderboardCategory category;
  final bool isDark;
  final bool showCrown;

  const _PodiumPlace({
    required this.entry,
    required this.rank,
    required this.height,
    required this.color,
    required this.category,
    required this.isDark,
    this.showCrown = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown for 1st place
        if (showCrown) ...[
          Icon(LucideIcons.crown, color: color, size: 28),
          const SizedBox(height: 4),
        ],

        // Avatar/Logo
        _buildAvatar(),

        const SizedBox(height: 8),

        // Name
        Text(
          entry.name,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 4),

        // Reports count
        Text(
          '${entry.reportsCount} reports',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),

        const SizedBox(height: 8),

        // Podium block
        Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color,
                color.withValues(alpha: 0.7),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar() {
    final size = rank == 1 ? 64.0 : 52.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: CircleAvatar(
        radius: size / 2 - 3,
        backgroundColor: AppColors.electricNavy.withValues(alpha: 0.2),
        backgroundImage: _getImageProvider(),
        child: _getImageProvider() == null ? _buildFallback() : null,
      ),
    );
  }

  ImageProvider? _getImageProvider() {
    final url = entry.avatarUrl ?? entry.logoUrl;
    if (url != null && url.isNotEmpty) {
      return NetworkImage(url);
    }
    return null;
  }

  Widget _buildFallback() {
    final IconData icon = switch (category) {
      LeaderboardCategory.users => LucideIcons.user,
      LeaderboardCategory.organizations => LucideIcons.building2,
      LeaderboardCategory.vessels => LucideIcons.ship,
    };

    return Icon(icon, color: AppColors.electricNavy, size: rank == 1 ? 28 : 22);
  }
}
