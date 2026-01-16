import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/report.dart';
import '../../providers/reports_map_provider.dart';

class HomeFilterBar extends StatelessWidget {
  const HomeFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportsMapProvider>(
      builder: (context, provider, _) {
        final visibleStatuses = provider.visibleStatuses;
        final isMyReports = provider.showOnlyMyReports;

        final isActiveSelected =
            visibleStatuses.contains(ReportStatus.pending) ||
                visibleStatuses.contains(ReportStatus.verified);
        final isRecoveredSelected =
            visibleStatuses.contains(ReportStatus.resolved);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // My Reports Chip
              _FilterChip(
                label: 'My Reports',
                icon: LucideIcons.user,
                isSelected: isMyReports,
                selectedColor: AppColors.electricNavy,
                onTap: () {
                  provider.setShowOnlyMyReports(!isMyReports);
                },
              ),
              const SizedBox(width: 8),

              // Active Reports Chip
              _FilterChip(
                label: 'Active',
                icon: LucideIcons.alertCircle,
                isSelected: isActiveSelected,
                selectedColor: const Color(0xFFEF4444),
                onTap: () {
                  final newStatuses = Set<ReportStatus>.from(visibleStatuses);
                  if (isActiveSelected) {
                    newStatuses.remove(ReportStatus.pending);
                    newStatuses.remove(ReportStatus.verified);
                  } else {
                    newStatuses.add(ReportStatus.pending);
                    newStatuses.add(ReportStatus.verified);
                  }
                  provider.setVisibleStatuses(newStatuses);
                },
              ),
              const SizedBox(width: 8),

              // Recovered Reports Chip
              _FilterChip(
                label: 'Recovered',
                icon: LucideIcons.checkCircle2,
                isSelected: isRecoveredSelected,
                selectedColor: AppColors.emerald,
                onTap: () {
                  final newStatuses = Set<ReportStatus>.from(visibleStatuses);
                  if (isRecoveredSelected) {
                    newStatuses.remove(ReportStatus.resolved);
                  } else {
                    newStatuses.add(ReportStatus.resolved);
                  }
                  provider.setVisibleStatuses(newStatuses);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor
              : (isDark ? const Color(0xFF2C2C2E) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
          border: Border.all(
            color: isSelected
                ? selectedColor
                : (isDark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.05)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
