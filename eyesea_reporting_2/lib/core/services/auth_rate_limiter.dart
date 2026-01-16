import 'dart:async';
import '../utils/logger.dart';

/// Rate limiter for authentication attempts with exponential backoff.
///
/// Prevents rapid-fire auth attempts that could:
/// - Trigger server-side rate limits
/// - Indicate brute force attempts
/// - Waste battery/bandwidth on doomed retries
class AuthRateLimiter {
  /// Maximum attempts before requiring a cooldown
  static const int maxAttempts = 3;

  /// Base delay for exponential backoff (doubles with each attempt)
  static const Duration baseDelay = Duration(seconds: 2);

  /// Maximum delay cap
  static const Duration maxDelay = Duration(minutes: 2);

  int _failedAttempts = 0;
  DateTime? _lastAttemptTime;
  DateTime? _lockoutUntil;

  /// Whether the user is currently locked out
  bool get isLockedOut {
    if (_lockoutUntil == null) return false;
    if (DateTime.now().isAfter(_lockoutUntil!)) {
      // Lockout expired
      _lockoutUntil = null;
      return false;
    }
    return true;
  }

  /// Time remaining until lockout expires (zero if not locked)
  Duration get lockoutRemaining {
    if (_lockoutUntil == null) return Duration.zero;
    final remaining = _lockoutUntil!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Number of failed attempts in current window
  int get failedAttempts => _failedAttempts;

  /// Check if an attempt is allowed and wait if necessary.
  /// Returns true if attempt can proceed, false if should abort.
  /// Throws [RateLimitedException] if user is locked out.
  Future<void> checkAndWait() async {
    if (isLockedOut) {
      final remaining = lockoutRemaining;
      throw RateLimitedException(
        'Too many failed attempts. Please wait ${_formatDuration(remaining)} before trying again.',
        retryAfter: remaining,
      );
    }

    // If we have recent failures, apply backoff delay
    if (_failedAttempts > 0 && _lastAttemptTime != null) {
      final delay = _calculateDelay();
      final timeSinceLastAttempt = DateTime.now().difference(_lastAttemptTime!);

      if (timeSinceLastAttempt < delay) {
        final waitTime = delay - timeSinceLastAttempt;
        AppLogger.debug(
          'Rate limiter: waiting ${waitTime.inSeconds}s before next attempt',
        );
        await Future.delayed(waitTime);
      }
    }
  }

  /// Record a successful authentication attempt. Resets the limiter.
  void recordSuccess() {
    _failedAttempts = 0;
    _lastAttemptTime = null;
    _lockoutUntil = null;
    AppLogger.debug('Rate limiter: reset after successful auth');
  }

  /// Record a failed authentication attempt.
  void recordFailure() {
    _failedAttempts++;
    _lastAttemptTime = DateTime.now();

    if (_failedAttempts >= maxAttempts) {
      // Apply lockout
      final lockoutDuration = _calculateDelay();
      _lockoutUntil = DateTime.now().add(lockoutDuration);
      AppLogger.warning(
        'Rate limiter: lockout applied for ${lockoutDuration.inSeconds}s '
        'after $_failedAttempts failed attempts',
      );
    } else {
      AppLogger.debug(
        'Rate limiter: attempt $_failedAttempts/$maxAttempts failed',
      );
    }
  }

  Duration _calculateDelay() {
    // Exponential backoff: 2s, 4s, 8s, 16s, ... capped at maxDelay
    final multiplier = 1 << (_failedAttempts - 1); // 2^(attempts-1)
    final delay = baseDelay * multiplier;
    return delay > maxDelay ? maxDelay : delay;
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes >= 1) {
      return '${d.inMinutes} minute${d.inMinutes > 1 ? 's' : ''}';
    }
    return '${d.inSeconds} second${d.inSeconds > 1 ? 's' : ''}';
  }

  /// Reset the rate limiter (e.g., when user logs out)
  void reset() {
    _failedAttempts = 0;
    _lastAttemptTime = null;
    _lockoutUntil = null;
  }
}

/// Exception thrown when rate limit is exceeded
class RateLimitedException implements Exception {
  final String message;
  final Duration retryAfter;

  RateLimitedException(this.message, {required this.retryAfter});

  @override
  String toString() => message;
}
