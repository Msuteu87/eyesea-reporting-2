import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A theme-aware SVG icon widget that automatically handles:
/// - Color theming (light/dark mode)
/// - Size consistency
/// - Semantic labels for accessibility
///
/// Example usage:
/// ```dart
/// SvgIcon(
///   AppIcons.pollutionPlastic,
///   size: 24,
///   color: AppColors.primary,
/// )
/// ```
class SvgIcon extends StatelessWidget {
  /// The asset path to the SVG file
  final String assetPath;

  /// Icon size (both width and height)
  final double size;

  /// Optional color override. If null, uses theme's icon color.
  final Color? color;

  /// Semantic label for accessibility
  final String? semanticLabel;

  /// Whether to apply theme color automatically
  final bool themed;

  const SvgIcon(
    this.assetPath, {
    super.key,
    this.size = 24,
    this.color,
    this.semanticLabel,
    this.themed = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = color ?? (themed ? theme.iconTheme.color : null);

    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      colorFilter: iconColor != null
          ? ColorFilter.mode(iconColor, BlendMode.srcIn)
          : null,
      semanticsLabel: semanticLabel,
      placeholderBuilder: (context) => SizedBox(
        width: size,
        height: size,
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}

/// Extension for easy icon creation from strings
extension SvgIconExtension on String {
  /// Convert asset path string to SvgIcon widget
  Widget toSvgIcon({
    double size = 24,
    Color? color,
    String? semanticLabel,
    bool themed = true,
  }) {
    return SvgIcon(
      this,
      size: size,
      color: color,
      semanticLabel: semanticLabel,
      themed: themed,
    );
  }
}

/// Convenience widget for pollution type icons with consistent styling
class PollutionTypeIcon extends StatelessWidget {
  final String pollutionType;
  final double size;
  final Color? color;

  const PollutionTypeIcon({
    super.key,
    required this.pollutionType,
    this.size = 32,
    this.color,
  });

  String get _iconPath {
    switch (pollutionType.toLowerCase()) {
      case 'plastic':
        return 'assets/icons/pollution_plastic.svg';
      case 'oil':
        return 'assets/icons/pollution_oil.svg';
      case 'debris':
        return 'assets/icons/pollution_debris.svg';
      case 'sewage':
        return 'assets/icons/pollution_sewage.svg';
      case 'fishing_gear':
        return 'assets/icons/pollution_fishing_gear.svg';
      default:
        return 'assets/icons/pollution_other.svg';
    }
  }

  Color get _defaultColor {
    switch (pollutionType.toLowerCase()) {
      case 'plastic':
        return const Color(0xFFE91E63); // Pink
      case 'oil':
        return const Color(0xFF212121); // Dark gray
      case 'debris':
        return const Color(0xFF795548); // Brown
      case 'sewage':
        return const Color(0xFF4CAF50); // Green
      case 'fishing_gear':
        return const Color(0xFF2196F3); // Blue
      default:
        return const Color(0xFF9E9E9E); // Gray
    }
  }

  @override
  Widget build(BuildContext context) {
    return SvgIcon(
      _iconPath,
      size: size,
      color: color ?? _defaultColor,
      semanticLabel: '$pollutionType pollution',
      themed: false,
    );
  }
}
