import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';

/// Floating action button for toggling layer filters.
/// Shows a layers icon and opens the filter sheet on tap.
class LayerFilterFab extends StatelessWidget {
  final VoidCallback onPressed;

  const LayerFilterFab({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(24),
          child: Icon(
            LucideIcons.layers,
            size: 22,
            color: isDark ? Colors.white : AppColors.inkBlack,
          ),
        ),
      ),
    );
  }
}
