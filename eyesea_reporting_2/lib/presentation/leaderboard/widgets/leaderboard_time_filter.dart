import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/leaderboard_data_source.dart';

/// Compact filter chips for selecting time range.
class LeaderboardTimeFilter extends StatelessWidget {
  final TimeFilter selected;
  final ValueChanged<TimeFilter> onChanged;

  const LeaderboardTimeFilter({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: TimeFilter.values.map((filter) {
        final isSelected = selected == filter;
        final label = switch (filter) {
          TimeFilter.last30Days => '30 Days',
          TimeFilter.last90Days => '90 Days',
          TimeFilter.lastYear => '1 Year',
        };

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GestureDetector(
            onTap: () => onChanged(filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.electricNavy.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.electricNavy
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.1)),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.electricNavy
                      : (isDark ? Colors.white70 : Colors.black54),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
