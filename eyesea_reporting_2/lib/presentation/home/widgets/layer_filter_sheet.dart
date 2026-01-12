import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/report.dart';

/// Bottom sheet for filtering map layers by report status.
/// Shows toggle switches for Active and Recovered reports.
class LayerFilterSheet extends StatelessWidget {
  final Set<ReportStatus> visibleStatuses;
  final ValueChanged<Set<ReportStatus>> onChanged;

  const LayerFilterSheet({
    super.key,
    required this.visibleStatuses,
    required this.onChanged,
  });

  /// Show the filter sheet and return the updated visible statuses
  static Future<Set<ReportStatus>?> show(
    BuildContext context, {
    required Set<ReportStatus> currentStatuses,
  }) async {
    return showModalBottomSheet<Set<ReportStatus>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // Allow sheet to size to content
      builder: (context) {
        Set<ReportStatus> statuses = Set.from(currentStatuses);
        return StatefulBuilder(
          builder: (context, setState) {
            return LayerFilterSheet(
              visibleStatuses: statuses,
              onChanged: (newStatuses) {
                setState(() {
                  statuses = newStatuses;
                });
              },
            );
          },
        );
      },
    ).then((value) => value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    // Active = pending + verified
    final showActive = visibleStatuses.contains(ReportStatus.pending) ||
        visibleStatuses.contains(ReportStatus.verified);
    // Recovered = resolved
    final showRecovered = visibleStatuses.contains(ReportStatus.resolved);

    return Container(
      margin: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottomPadding + 80),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Active Reports row
          _CompactToggleRow(
            label: 'Active',
            color: AppColors.oceanBlue,
            value: showActive,
            onChanged: (value) {
              final newStatuses = Set<ReportStatus>.from(visibleStatuses);
              if (value) {
                newStatuses.add(ReportStatus.pending);
                newStatuses.add(ReportStatus.verified);
              } else {
                newStatuses.remove(ReportStatus.pending);
                newStatuses.remove(ReportStatus.verified);
              }
              onChanged(newStatuses);
              Navigator.pop(context, newStatuses);
            },
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: isDark ? Colors.white12 : Colors.black12,
          ),
          // Recovered Reports row
          _CompactToggleRow(
            label: 'Recovered',
            color: Colors.green,
            value: showRecovered,
            onChanged: (value) {
              final newStatuses = Set<ReportStatus>.from(visibleStatuses);
              if (value) {
                newStatuses.add(ReportStatus.resolved);
              } else {
                newStatuses.remove(ReportStatus.resolved);
              }
              onChanged(newStatuses);
              Navigator.pop(context, newStatuses);
            },
          ),
        ],
      ),
    );
  }
}

/// Compact iOS-style toggle row
class _CompactToggleRow extends StatelessWidget {
  final String label;
  final Color color;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CompactToggleRow({
    required this.label,
    required this.color,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          // Color indicator dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w400,
                color: isDark ? Colors.white : Colors.black,
                letterSpacing: -0.4,
              ),
            ),
          ),
          SizedBox(
            height: 31,
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeTrackColor: color,
            ),
          ),
        ],
      ),
    );
  }
}
