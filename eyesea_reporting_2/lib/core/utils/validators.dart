/// Utility class for input validation.
class Validators {
  Validators._();

  /// RFC 5322 compliant email regex pattern
  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$',
  );

  /// Validates email format.
  /// Returns null if valid, error message if invalid.
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }

    final trimmed = value.trim();

    if (!_emailRegex.hasMatch(trimmed)) {
      return 'Please enter a valid email address';
    }

    // Additional length checks per RFC 5321
    if (trimmed.length > 254) {
      return 'Email address is too long';
    }

    final parts = trimmed.split('@');
    if (parts.length != 2) {
      return 'Please enter a valid email address';
    }

    if (parts[0].length > 64) {
      return 'Email local part is too long';
    }

    return null;
  }

  /// Validates password strength.
  /// Returns null if valid, error message if invalid.
  static String? validatePassword(String? value, {int minLength = 8}) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }

    if (value.length < minLength) {
      return 'Password must be at least $minLength characters';
    }

    return null;
  }

  /// Validates that two passwords match.
  /// Returns null if valid, error message if invalid.
  static String? validatePasswordMatch(String? value, String? original) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != original) {
      return 'Passwords do not match';
    }

    return null;
  }
}
