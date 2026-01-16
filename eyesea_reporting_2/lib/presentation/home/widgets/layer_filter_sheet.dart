import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../domain/entities/report.dart';

/// Result from the filter sheet containing both status and user filters
class LayerFilterResult {
  final Set<ReportStatus> statuses;
  final bool showOnlyMyReports;
  final bool isHeatmapEnabled; // New

  const LayerFilterResult({
    required this.statuses,
    required this.showOnlyMyReports,
    required this.isHeatmapEnabled,
  });
}

/// Bottom sheet for filtering map layers by report status and ownership.
/// Shows toggle switches for My Reports, Active, and Recovered reports.
class LayerFilterSheet extends StatelessWidget {
  final Set<ReportStatus> visibleStatuses;
  final bool showOnlyMyReports;
  final bool isHeatmapEnabled;
  final ValueChanged<Set<ReportStatus>> onStatusChanged;
  final ValueChanged<bool> onMyReportsChanged;
  final ValueChanged<bool> onHeatmapChanged;

  const LayerFilterSheet({
    super.key,
    required this.visibleStatuses,
    required this.showOnlyMyReports,
    required this.isHeatmapEnabled,
    required this.onStatusChanged,
    required this.onMyReportsChanged,
    required this.onHeatmapChanged,
  });

  /// Show the filter sheet and return the updated filter result
  static Future<LayerFilterResult?> show(
    BuildContext context, {
    required Set<ReportStatus> currentStatuses,
    required bool showOnlyMyReports,
    required bool isHeatmapEnabled,
  }) async {
    return showModalBottomSheet<LayerFilterResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        Set<ReportStatus> statuses = Set.from(currentStatuses);
        bool myReports = showOnlyMyReports;
        bool heatmap = isHeatmapEnabled;
        return StatefulBuilder(
          builder: (context, setState) {
            return LayerFilterSheet(
              visibleStatuses: statuses,
              showOnlyMyReports: myReports,
              isHeatmapEnabled: heatmap,
              onStatusChanged: (newStatuses) {
                setState(() {
                  statuses = newStatuses;
                });
              },
              onMyReportsChanged: (value) {
                setState(() {
                  myReports = value;
                });
              },
              onHeatmapChanged: (value) {
                setState(() {
                  heatmap = value;
                });
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    // Active = pending + verified
    // Nav bar is ~90pt + home indicator, add generous spacing above it
    const navBarHeight = 100.0;
    const spacing = 16.0;

    return Container(
      margin: EdgeInsets.fromLTRB(
          16, 0, 16, bottomPadding + navBarHeight + spacing),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Global Heatmap Toggle
          _CompactToggleRow(
            label: 'Global Heatmap',
            icon: LucideIcons.flame, // Fire icon for heatmap
            color: Colors.orangeAccent,
            value: isHeatmapEnabled,
            onChanged: (value) {
              onHeatmapChanged(value);
              Navigator.pop(
                context,
                LayerFilterResult(
                  statuses: visibleStatuses,
                  showOnlyMyReports: showOnlyMyReports,
                  isHeatmapEnabled: value,
                ),
              );
            },
          ),
          const SizedBox(
              height: 8), // Bottom spacing since other items are gone
        ],
      ),
    );
  }
}

/// Compact iOS-style toggle row
class _CompactToggleRow extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CompactToggleRow({
    required this.label,
    this.icon,
    required this.color,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // Icon or color indicator dot
          if (icon != null)
            Icon(
              icon,
              size: 18,
              color: color,
            )
          else
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
