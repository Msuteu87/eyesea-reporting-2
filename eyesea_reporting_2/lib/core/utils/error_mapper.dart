import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../errors/exceptions.dart';
import 'logger.dart';

/// Maps internal exceptions to user-friendly messages while logging full details.
class ErrorMapper {
  ErrorMapper._();

  /// Maps authentication errors to user-friendly messages.
  /// Logs the full error internally for debugging.
  static AuthException mapAuthError(Object error, [StackTrace? stackTrace]) {
    AppLogger.error('Auth error occurred', error, stackTrace);

    final errorStr = error.toString().toLowerCase();

    // Supabase AuthException
    if (error is supabase.AuthException) {
      final message = error.message.toLowerCase();

      if (message.contains('invalid login credentials') ||
          message.contains('invalid_credentials')) {
        return AuthException(message: 'Invalid email or password.');
      }
      if (message.contains('email not confirmed')) {
        return AuthException(message: 'Please verify your email address.');
      }
      if (message.contains('user already registered') ||
          message.contains('already exists')) {
        return AuthException(
            message: 'An account with this email already exists.');
      }
      if (message.contains('password') && message.contains('weak')) {
        return AuthException(
            message: 'Password is too weak. Use at least 8 characters.');
      }
      if (message.contains('rate limit') ||
          message.contains('too many requests')) {
        return AuthException(
            message: 'Too many attempts. Please try again later.');
      }
      if (message.contains('session expired') ||
          message.contains('refresh_token')) {
        return AuthException(message: 'Session expired. Please sign in again.');
      }
    }

    // PostgrestException (database errors) - never expose details
    if (error is supabase.PostgrestException) {
      return AuthException(message: 'An error occurred. Please try again.');
    }

    // Network/connectivity errors
    if (errorStr.contains('socketexception') ||
        errorStr.contains('failed host lookup') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('network is unreachable')) {
      return AuthException(message: 'Network error. Check your connection.');
    }

    // Default fallback - never expose raw error
    return AuthException(message: 'Authentication failed. Please try again.');
  }

  /// Maps general server errors to user-friendly messages.
  static ServerException mapServerError(Object error,
      [StackTrace? stackTrace]) {
    AppLogger.error('Server error occurred', error, stackTrace);

    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('socketexception') ||
        errorStr.contains('failed host lookup') ||
        errorStr.contains('network is unreachable')) {
      return ServerException(message: 'Network error. Check your connection.');
    }

    if (error is supabase.PostgrestException) {
      return ServerException(message: 'Server error. Please try again.');
    }

    return ServerException(message: 'Something went wrong. Please try again.');
  }
}
