import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  // Base text theme with Space Grotesk
  static TextTheme get _baseTextTheme => GoogleFonts.spaceGroteskTextTheme();

  static ThemeData get lightTheme {
    return ThemeData(
      textTheme: _baseTextTheme.copyWith(
        headlineLarge: _baseTextTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.darkGunmetal,
        ),
        headlineMedium: _baseTextTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.darkGunmetal,
        ),
        headlineSmall: _baseTextTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.darkGunmetal,
        ),
        titleLarge: _baseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.darkGunmetal,
        ),
        titleMedium: _baseTextTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.darkGunmetal,
        ),
        bodyLarge: _baseTextTheme.bodyLarge?.copyWith(
          color: AppColors.darkGunmetal,
        ),
        bodyMedium: _baseTextTheme.bodyMedium?.copyWith(
          color: AppColors.coolGray,
        ),
        bodySmall: _baseTextTheme.bodySmall?.copyWith(
          color: AppColors.coolGray,
        ),
        labelLarge: _baseTextTheme.labelLarge?.copyWith(
          color: AppColors.darkGunmetal,
        ),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.electricNavy,
        primary: AppColors.electricNavy,
        secondary: AppColors.coolGray,
        surface: AppColors.culturedWhite,
        error: AppColors.error,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.culturedWhite,
      cardColor: AppColors.pureWhite,

      // Card Theme
      cardTheme: CardThemeData(
        color: AppColors.pureWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        shadowColor: Colors.black.withValues(alpha: 0.05),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.pureWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.electricNavy, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: TextStyle(color: AppColors.coolGray.withValues(alpha: 0.7)),
      ),

      // Button Theme
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.electricNavy,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.pureWhite,
          foregroundColor: AppColors.darkGunmetal,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: AppColors.coolGray.withValues(alpha: 0.2),
        thickness: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    final darkTextTheme = GoogleFonts.spaceGroteskTextTheme(
      ThemeData.dark().textTheme,
    );
    return ThemeData(
      textTheme: darkTextTheme.copyWith(
        headlineLarge: darkTextTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.porcelain,
        ),
        headlineMedium: darkTextTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.porcelain,
        ),
        headlineSmall: darkTextTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.porcelain,
        ),
        titleLarge: darkTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.porcelain,
        ),
        titleMedium: darkTextTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.porcelain,
        ),
        bodyLarge: darkTextTheme.bodyLarge?.copyWith(
          color: AppColors.porcelain,
        ),
        bodyMedium: darkTextTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.7),
        ),
        bodySmall: darkTextTheme.bodySmall?.copyWith(
          color: Colors.white.withValues(alpha: 0.6),
        ),
        labelLarge: darkTextTheme.labelLarge?.copyWith(
          color: AppColors.porcelain,
        ),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.electricNavy,
        primary: AppColors.electricNavy,
        secondary: AppColors.porcelain,
        surface: AppColors.inkBlack,
        error: AppColors.error,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.inkBlack,
      cardColor: AppColors.darkSurface,

      // Card Theme
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        shadowColor: Colors.black.withValues(alpha: 0.3),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.electricNavy, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
      ),

      // Button Theme
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.electricNavy,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkSurface,
          foregroundColor: AppColors.porcelain,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.1),
        thickness: 1,
      ),
    );
  }
}
