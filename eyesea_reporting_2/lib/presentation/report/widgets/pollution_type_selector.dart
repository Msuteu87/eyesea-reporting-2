import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/utils/pollution_calculations.dart';
import '../../../domain/entities/report.dart';

class PollutionTypeSelector extends StatelessWidget {
  final Set<PollutionType> selectedTypes;
  final ValueChanged<PollutionType> onTypeToggled;
  final bool isDark;
  final Color primaryColor;
  final Map<PollutionType, int> typeCounts;
  final void Function(PollutionType, int)? onCountChanged;
  final bool showSummary;

  const PollutionTypeSelector({
    super.key,
    required this.selectedTypes,
    required this.onTypeToggled,
    required this.isDark,
    required this.primaryColor,
    required this.typeCounts,
    this.onCountChanged,
    this.showSummary = false,
  });

  @override
  Widget build(BuildContext context) {
    final totalItems = typeCounts.values.fold(0, (sum, count) => sum + count);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Existing scrollable type selector
        ShaderMask(
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.white,
                Colors.white,
                Colors.white.withValues(alpha: 0.05),
              ],
              stops: const [0.0, 0.85, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            clipBehavior: Clip.none,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: PollutionType.values.map((type) {
                final isSelected = selectedTypes.contains(type);
                final count = typeCounts[type] ?? 0;
                final icon = _getPollutionIcon(type);

            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon Circle
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onTypeToggled(type),
                      borderRadius: BorderRadius.circular(40),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? primaryColor
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.grey[200]),
                          border: Border.all(
                            color: isSelected
                                ? primaryColor
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.grey[300]!),
                            width: 1.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  )
                                ]
                              : null,
                        ),
                        child: Icon(
                          icon,
                          size: 24,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.grey[700]),
                        ),
                      ),
                    ),
                  ),

                  // Count Control (only if supported)
                  if (onCountChanged != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildMiniButton(
                            icon: LucideIcons.minus,
                            onTap: () {
                              if (count > 0) onCountChanged!(type, count - 1);
                            },
                            isDark: isDark,
                          ),
                          SizedBox(
                            width: 24,
                            child: Text(
                              '$count',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.grey[800],
                              ),
                            ),
                          ),
                          _buildMiniButton(
                            icon: LucideIcons.plus,
                            onTap: () => onCountChanged!(type, count + 1),
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Type Label
                    SizedBox(
                      width: 72,
                      child: Text(
                        type.displayLabel,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? primaryColor
                              : (isDark ? Colors.white60 : Colors.grey[600]),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
            ),
          ),
        ),

        // NEW: Summary footer (conditionally shown)
        if (showSummary && totalItems > 0) ...[
          const SizedBox(height: 12),
          _buildSummaryFooter(context),
        ],
      ],
    );
  }

  Widget _buildSummaryFooter(BuildContext context) {
    final totalItems = typeCounts.values.fold(0, (sum, count) => sum + count);
    final totalWeight = PollutionCalculations.calculateTotalWeight(typeCounts);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey[300]!,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Weight metric
          _buildMetricChip(
            icon: LucideIcons.scale,
            label: PollutionCalculations.formatWeight(totalWeight),
            subtitle: 'Est. Weight',
            color: primaryColor,
            isDark: isDark,
          ),

          // Divider
          Container(
            width: 1,
            height: 30,
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey[300],
          ),

          // Items metric
          _buildMetricChip(
            icon: LucideIcons.package,
            label: '$totalItems',
            subtitle: totalItems == 1 ? 'Item' : 'Items',
            color: primaryColor,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.grey[900],
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white60 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Icon(
          icon,
          size: 14,
          color: isDark ? Colors.white70 : Colors.grey[600],
        ),
      ),
    );
  }

  IconData _getPollutionIcon(PollutionType type) {
    switch (type) {
      case PollutionType.plastic:
        return LucideIcons.milk; // Bottle icon
      case PollutionType.oil:
        return LucideIcons.droplet;
      case PollutionType.debris:
        return LucideIcons.trash2;
      case PollutionType.sewage:
        return LucideIcons.waves;
      case PollutionType.fishingGear:
        return LucideIcons.anchor;
      case PollutionType.container:
        return LucideIcons.box;
      case PollutionType.other:
        return LucideIcons.helpCircle;
    }
  }
}
