import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/social_feed_provider.dart';

/// Apple-style segmented control for filtering feed by location scope
class FeedFilterControl extends StatelessWidget {
  final FeedFilter selected;
  final ValueChanged<FeedFilter> onChanged;
  final String? countryName;
  final String? cityName;

  const FeedFilterControl({
    super.key,
    required this.selected,
    required this.onChanged,
    this.countryName,
    this.cityName,
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
            filter: FeedFilter.nearby,
            icon: LucideIcons.radar,
            label: 'Nearby',
            isDark: isDark,
          ),
          _buildSegment(
            context,
            filter: FeedFilter.country,
            icon: LucideIcons.flag,
            label: countryName ?? 'Country',
            isDark: isDark,
            enabled: countryName != null,
          ),
          _buildSegment(
            context,
            filter: FeedFilter.world,
            icon: LucideIcons.globe,
            label: 'World',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSegment(
    BuildContext context, {
    required FeedFilter filter,
    required IconData icon,
    required String label,
    required bool isDark,
    bool enabled = true,
  }) {
    final isSelected = selected == filter;

    return Expanded(
      child: GestureDetector(
        onTap: enabled ? () => onChanged(filter) : null,
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
                color: _getColor(isSelected, enabled, isDark),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _getColor(isSelected, enabled, isDark),
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

  Color _getColor(bool isSelected, bool enabled, bool isDark) {
    if (!enabled) {
      return isDark
          ? Colors.white.withValues(alpha: 0.3)
          : Colors.black.withValues(alpha: 0.3);
    }
    if (isSelected) {
      return Colors.white;
    }
    return isDark
        ? Colors.white.withValues(alpha: 0.6)
        : Colors.black.withValues(alpha: 0.6);
  }
}
