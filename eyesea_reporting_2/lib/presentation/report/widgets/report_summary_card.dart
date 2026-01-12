import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/pollution_calculations.dart';
import '../../../domain/entities/report.dart';

/// Environmental impact card showing ecosystem risk, cleanup estimates, and educational facts
class ReportSummaryCard extends StatelessWidget {
  final Map<PollutionType, int> typeCounts;
  final int severity;
  final bool hasLocation;
  final bool hasPhoto;
  final List<String> sceneLabels;
  final bool isDark;

  const ReportSummaryCard({
    super.key,
    required this.typeCounts,
    required this.severity,
    required this.hasLocation,
    required this.hasPhoto,
    required this.sceneLabels,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final accentColor = theme.colorScheme.secondary;

    // Calculate impact metrics
    final impact = PollutionCalculations.calculateImpact(
      typeCounts: typeCounts,
      severity: severity,
      sceneLabels: sceneLabels,
    );

    final educationalFact = PollutionCalculations.getEducationalFact(
      typeCounts: typeCounts,
      sceneLabels: sceneLabels,
    );

    final totalItems = typeCounts.values.fold(0, (sum, count) => sum + count);

    // Don't show if no items selected
    if (totalItems == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                LucideIcons.zap,
                size: 18,
                color: accentColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Estimated Impact',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.grey[900],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Impact metrics row (condensed)
          Row(
            children: [
              // Ecosystem risk
              Expanded(
                child: _buildImpactMetric(
                  icon: LucideIcons.waves,
                  label: 'Ecosystem Risk',
                  value: impact['riskLevel'],
                  color: _getRiskColor(impact['ecosystemRisk']),
                  isDark: isDark,
                ),
              ),

              const SizedBox(width: 8),

              // Cleanup time
              Expanded(
                child: _buildImpactMetric(
                  icon: LucideIcons.clock,
                  label: 'Cleanup Time',
                  value: impact['cleanupFormatted'],
                  color: primaryColor,
                  isDark: isDark,
                ),
              ),

              const SizedBox(width: 8),

              // Volunteers needed
              Expanded(
                child: _buildImpactMetric(
                  icon: LucideIcons.users,
                  label: 'Team Size',
                  value: impact['volunteersFormatted'],
                  color: accentColor,
                  isDark: isDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Educational fact
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.lightbulb,
                  size: 14,
                  color: accentColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    educationalFact,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: isDark ? Colors.white70 : Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildImpactMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: isDark ? Colors.white60 : Colors.grey[600],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Color _getRiskColor(int risk) {
    switch (risk) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.lightGreen;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.deepOrange;
      case 5:
        return AppColors.punchRed;
      default:
        return Colors.orange;
    }
  }
}
