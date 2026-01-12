import 'package:flutter/material.dart';

class AppColors {
  // Vibrant Palette
  static const Color inkBlack = Color(0xFF011627);
  static const Color porcelain = Color(0xFFFDFFFC);
  static const Color lightSeaGreen = Color(0xFF2EC4B6);
  static const Color deepNavy = Color(0xFF0F2C59); // Deep Navy from new logo
  static const Color punchRed = Color(0xFFE71D36);
  static const Color amberGlow = Color(0xFFFF9F1C);
  static const Color oceanBlue = Color(0xFF0077BE);

  // Semantic Aliases
  static const Color primary =
      deepNavy; // Default primary, override in UI for light/dark specific
  static const Color secondary = inkBlack;
  static const Color backgroundLight = porcelain;
  static const Color backgroundDark = inkBlack;
  static const Color error = punchRed;
  static const Color warning = amberGlow;
  static const Color successGreen =
      Color(0xFF22C55E); // Green for success states

  // Legacy aliases to prevent breakages during migration (mapped to new palette)
  static const Map<int, Color> shark = {
    50: porcelain,
    100: porcelain,
    200: porcelain,
    300: lightSeaGreen,
    400: lightSeaGreen,
    500: lightSeaGreen,
    600: inkBlack,
    700: inkBlack,
    800: inkBlack,
    900: inkBlack,
    950: inkBlack,
  };
}
