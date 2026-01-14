import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/entities/user.dart';
import '../utils/logger.dart';
import 'secure_storage_service.dart';

/// Service to cache user profile for offline access.
/// Uses encrypted Hive storage following the same pattern as ReportQueueService.
class ProfileCacheService {
  static const String _boxName = 'cached_profile';
  static const String _profileKey = 'user_profile';
  static const String _cachedAtKey = 'cached_at';

  Box<String>? _box;

  /// Initialize encrypted Hive box for profile storage
  Future<void> initialize() async {
    final encryptionKey = await SecureStorageService.getOrCreateHiveKey();

    try {
      _box = await Hive.openBox<String>(
        _boxName,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
      AppLogger.info('Profile cache initialized');
    } catch (e) {
      AppLogger.warning('Migrating profile cache to encrypted storage');
      await Hive.deleteBoxFromDisk(_boxName);
      _box = await Hive.openBox<String>(
        _boxName,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
    }
  }

  /// Cache a user profile
  Future<void> cacheProfile(UserEntity user) async {
    if (_box == null) {
      AppLogger.warning('Profile cache not initialized');
      return;
    }

    final profileJson = jsonEncode(_userToJson(user));
    await _box!.put(_profileKey, profileJson);
    await _box!.put(_cachedAtKey, DateTime.now().toIso8601String());

    AppLogger.info('Cached profile for user: ${user.id}');
  }

  /// Retrieve cached profile, or null if not found
  Future<UserEntity?> getCachedProfile() async {
    if (_box == null) {
      AppLogger.warning('Profile cache not initialized');
      return null;
    }

    final profileJson = _box!.get(_profileKey);
    if (profileJson == null) {
      return null;
    }

    try {
      final json = jsonDecode(profileJson) as Map<String, dynamic>;
      final user = _userFromJson(json);
      AppLogger.info('Loaded cached profile for user: ${user.id}');
      return user;
    } catch (e) {
      AppLogger.error('Failed to parse cached profile', e);
      return null;
    }
  }

  /// Get the timestamp when profile was last cached
  Future<DateTime?> getCachedAt() async {
    if (_box == null) return null;

    final cachedAtStr = _box!.get(_cachedAtKey);
    if (cachedAtStr == null) return null;

    try {
      return DateTime.parse(cachedAtStr);
    } catch (e) {
      return null;
    }
  }

  /// Check if cached profile matches a given user ID
  Future<bool> hasCachedProfileForUser(String userId) async {
    final cached = await getCachedProfile();
    return cached?.id == userId;
  }

  /// Clear cached profile (call on logout)
  Future<void> clearCache() async {
    if (_box == null) return;

    await _box!.clear();
    AppLogger.info('Profile cache cleared');
  }

  /// Convert UserEntity to JSON map for storage
  Map<String, dynamic> _userToJson(UserEntity user) {
    return {
      'id': user.id,
      'email': user.email,
      'displayName': user.displayName,
      'avatarUrl': user.avatarUrl,
      'country': user.country,
      'city': user.city,
      'role': user.role.name,
      'reportsCount': user.reportsCount,
      'streakDays': user.streakDays,
      'orgName': user.orgName,
      'orgId': user.orgId,
      'orgLogoUrl': user.orgLogoUrl,
      'currentVesselId': user.currentVesselId,
      'currentVesselName': user.currentVesselName,
      'ambassadorRegionCountry': user.ambassadorRegionCountry,
      'ambassadorRegionName': user.ambassadorRegionName,
    };
  }

  /// Convert JSON map back to UserEntity
  UserEntity _userFromJson(Map<String, dynamic> json) {
    return UserEntity(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      country: json['country'] as String?,
      city: json['city'] as String?,
      role: UserEntity.parseRole(json['role'] as String?),
      reportsCount: json['reportsCount'] as int? ?? 0,
      streakDays: json['streakDays'] as int? ?? 0,
      orgName: json['orgName'] as String?,
      orgId: json['orgId'] as String?,
      orgLogoUrl: json['orgLogoUrl'] as String?,
      currentVesselId: json['currentVesselId'] as String?,
      currentVesselName: json['currentVesselName'] as String?,
      ambassadorRegionCountry: json['ambassadorRegionCountry'] as String?,
      ambassadorRegionName: json['ambassadorRegionName'] as String?,
    );
  }
}
