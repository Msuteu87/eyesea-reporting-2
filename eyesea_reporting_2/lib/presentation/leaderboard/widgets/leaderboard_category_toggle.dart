import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/leaderboard_data_source.dart';

/// Apple-style segmented control for switching between leaderboard categories.
class LeaderboardCategoryToggle extends StatelessWidget {
  final LeaderboardCategory selected;
  final ValueChanged<LeaderboardCategory> onChanged;

  const LeaderboardCategoryToggle({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildSegment(
            context,
            category: LeaderboardCategory.users,
            icon: LucideIcons.users,
            label: 'Users',
            isDark: isDark,
          ),
          _buildSegment(
            context,
            category: LeaderboardCategory.organizations,
            icon: LucideIcons.building2,
            label: 'Orgs',
            isDark: isDark,
          ),
          _buildSegment(
            context,
            category: LeaderboardCategory.vessels,
            icon: LucideIcons.ship,
            label: 'Ships',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSegment(
    BuildContext context, {
    required LeaderboardCategory category,
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = selected == category;

    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(category),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.electricNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : Colors.black.withValues(alpha: 0.6)),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.6)
                            : Colors.black.withValues(alpha: 0.6)),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
