import 'package:flutter/material.dart';

class AppColors {
  // ============================================
  // Premium "Clean Ocean & Slate" Palette
  // ============================================

  // Primary Colors
  static const Color electricNavy = Color(0xFF2563EB); // Premium primary blue
  static const Color deepIndigo = Color(0xFF1D4ED8); // Gradient end color
  static const Color deepNavy = Color(0xFF0F2C59); // Deep Navy from logo

  // Backgrounds
  static const Color culturedWhite = Color(0xFFF8F9FC); // Soft off-white bg
  static const Color pureWhite = Color(0xFFFFFFFF); // Card backgrounds
  static const Color darkSurface = Color(0xFF1E1E1E); // Dark mode cards

  // Text Colors
  static const Color darkGunmetal = Color(0xFF1E293B); // Headings (light mode)
  static const Color coolGray = Color(0xFF64748B); // Body text (light mode)

  // Accent Colors
  static const Color emerald = Color(0xFF10B981); // Success/nature
  static const Color lightSeaGreen = Color(0xFF2EC4B6); // Teal accent
  static const Color punchRed = Color(0xFFE71D36); // Error/warning
  static const Color amberGlow = Color(0xFFFF9F1C); // Warning states

  // Legacy Colors (kept for compatibility)
  static const Color inkBlack = Color(0xFF011627);
  static const Color porcelain = Color(0xFFFDFFFC);
  static const Color oceanBlue = Color(0xFF0077BE);

  // ============================================
  // Semantic Aliases
  // ============================================
  static const Color primary = electricNavy;
  static const Color secondary = darkGunmetal;
  static const Color backgroundLight = culturedWhite;
  static const Color backgroundDark = inkBlack;
  static const Color error = punchRed;
  static const Color warning = amberGlow;
  static const Color successGreen = emerald;

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
