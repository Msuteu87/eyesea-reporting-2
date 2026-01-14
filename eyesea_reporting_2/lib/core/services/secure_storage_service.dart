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
}
