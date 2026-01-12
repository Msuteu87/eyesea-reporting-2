import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';

/// Widget for selecting pollution severity level (1-5 scale)
class SeveritySelector extends StatelessWidget {
  final int severity;
  final ValueChanged<int> onSeverityChanged;
  final bool isDark;

  const SeveritySelector({
    super.key,
    required this.severity,
    required this.onSeverityChanged,
    required this.isDark,
  });

  static const severityLabels = ['Minor', 'Low', 'Moderate', 'High', 'Critical'];
  static const severityColors = [
    Colors.green,
    Colors.lightGreen,
    Colors.orange,
    Colors.deepOrange,
    AppColors.punchRed,
  ];

  @override
  Widget build(BuildContext context) {
    final currentColor = severityColors[severity - 1];
    final currentLabel = severityLabels[severity - 1];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Slider
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: currentColor,
            inactiveTrackColor:
                isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200],
            thumbColor: currentColor,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayColor: currentColor.withValues(alpha: 0.2),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
            valueIndicatorColor: currentColor,
            valueIndicatorTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Slider(
            value: severity.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: currentLabel,
            onChanged: (val) => onSeverityChanged(val.round()),
          ),
        ),

        const SizedBox(height: 8),

        // Labels Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Min label
            Text(
              'Minor',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
            ),

            // Current severity badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: currentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: currentColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: currentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currentLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: currentColor,
                    ),
                  ),
                ],
              ),
            ),

            // Max label
            Text(
              'Critical',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 200.ms);
  }
}
