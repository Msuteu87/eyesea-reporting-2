import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'utils/logger.dart';

/// Centralized secrets management that loads from .env file or build-time environment variables.
/// 
/// Priority order:
/// 1. Build-time --dart-define flags (for production)
/// 2. .env file (for development)
/// 3. Empty string (fallback)
/// 
/// Usage:
/// - Development: Create `.env` file in project root
/// - Production: Use --dart-define flags during build:
///   flutter build ios --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... --dart-define=MAPBOX_ACCESS_TOKEN=...
class Secrets {
  /// Supabase project URL
  static String get supabaseUrl {
    // Priority: dart-define (production) > .env (development) > empty
    final value = const String.fromEnvironment('SUPABASE_URL', defaultValue: '').isNotEmpty
        ? const String.fromEnvironment('SUPABASE_URL')
        : (dotenv.env['SUPABASE_URL'] ?? '');
    
    if (kDebugMode && value.isEmpty) {
      AppLogger.warning('SUPABASE_URL is not configured. App may not work correctly.');
    }
    
    return value;
  }

  /// Supabase anonymous key
  static String get supabaseAnonKey {
    final value = const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '').isNotEmpty
        ? const String.fromEnvironment('SUPABASE_ANON_KEY')
        : (dotenv.env['SUPABASE_ANON_KEY'] ?? '');
    
    if (kDebugMode && value.isEmpty) {
      AppLogger.warning('SUPABASE_ANON_KEY is not configured. App may not work correctly.');
    }
    
    return value;
  }

  /// Mapbox access token
  static String get mapboxAccessToken {
    final value = const String.fromEnvironment('MAPBOX_ACCESS_TOKEN', defaultValue: '').isNotEmpty
        ? const String.fromEnvironment('MAPBOX_ACCESS_TOKEN')
        : (dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '');
    
    if (kDebugMode && value.isEmpty) {
      AppLogger.warning('MAPBOX_ACCESS_TOKEN is not configured. Maps may not work.');
    }
    
    return value;
  }

  /// Check if all required secrets are configured
  static bool get isConfigured {
    final configured = supabaseUrl.isNotEmpty && 
           supabaseAnonKey.isNotEmpty && 
           mapboxAccessToken.isNotEmpty;
    
    if (!configured && kDebugMode) {
      AppLogger.error('Secrets not fully configured. Missing:', null);
      if (supabaseUrl.isEmpty) AppLogger.error('  - SUPABASE_URL', null);
      if (supabaseAnonKey.isEmpty) AppLogger.error('  - SUPABASE_ANON_KEY', null);
      if (mapboxAccessToken.isEmpty) AppLogger.error('  - MAPBOX_ACCESS_TOKEN', null);
    }
    
    return configured;
  }
}
