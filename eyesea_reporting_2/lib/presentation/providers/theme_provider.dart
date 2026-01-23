import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing app theme mode with persistence.
/// Allows immediate theme switching without app restart.
class ThemeProvider extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  /// Current theme mode
  ThemeMode get themeMode => _themeMode;

  /// Initialize by loading saved preference
  /// Defaults to system mode if no preference is saved
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt(_themeModeKey);
    if (savedIndex != null && savedIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[savedIndex];
    } else {
      // Explicitly set to system mode as default (no saved preference)
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  /// Set theme mode and persist to storage
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, mode.index);
  }
}
