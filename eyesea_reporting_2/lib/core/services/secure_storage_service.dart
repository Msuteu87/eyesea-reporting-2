import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for storing sensitive data securely.
/// Uses platform-specific secure storage (Keychain on iOS, EncryptedSharedPreferences on Android).
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Keys for secure storage
  static const _keyHiveEncryptionKey = 'hive_encryption_key';
  static const _keyOnboardingPrefix = 'onboarding_complete_';
  static const _keyTermsAccepted = 'terms_accepted';

  /// Generate and store a 32-byte encryption key for Hive, or retrieve existing one.
  /// Returns a List<int> suitable for HiveAesCipher.
  static Future<List<int>> getOrCreateHiveKey() async {
    final existing = await _storage.read(key: _keyHiveEncryptionKey);

    if (existing != null) {
      // Decode the stored base64 key
      return base64Decode(existing);
    }

    // Generate a cryptographically secure 32-byte key for AES-256
    final random = Random.secure();
    final key = List<int>.generate(32, (_) => random.nextInt(256));

    // Store as base64 for safe string storage
    await _storage.write(key: _keyHiveEncryptionKey, value: base64Encode(key));

    return key;
  }

  /// Check if a Hive encryption key exists (useful for migration scenarios)
  static Future<bool> hasHiveKey() async {
    final existing = await _storage.read(key: _keyHiveEncryptionKey);
    return existing != null;
  }

  /// Clear all secure storage (for complete logout/reset)
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // ===== Onboarding Status =====

  /// Check if onboarding is complete for a specific user
  static Future<bool> isOnboardingComplete(String userId) async {
    final value = await _storage.read(key: '$_keyOnboardingPrefix$userId');
    return value == 'true';
  }

  /// Mark onboarding as complete for a specific user
  static Future<void> setOnboardingComplete(String userId, bool complete) async {
    await _storage.write(
      key: '$_keyOnboardingPrefix$userId',
      value: complete.toString(),
    );
  }

  // ===== Terms Acceptance =====

  /// Check if terms have been accepted
  static Future<bool> hasAcceptedTerms() async {
    final value = await _storage.read(key: _keyTermsAccepted);
    return value == 'true';
  }

  /// Mark terms as accepted
  static Future<void> setTermsAccepted(bool accepted) async {
    await _storage.write(
      key: _keyTermsAccepted,
      value: accepted.toString(),
    );
  }

  /// Clear user-specific data (for logout while preserving global settings)
  static Future<void> clearUserData(String userId) async {
    await _storage.delete(key: '$_keyOnboardingPrefix$userId');
  }
}
