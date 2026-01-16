import 'dart:async';
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

import '../utils/logger.dart';
import 'secure_storage_service.dart';

// TODO: [CACHE-COHERENCY] Replace time-based expiry with event-driven invalidation
// Current: 24-hour cache expiry (_cacheExpiry) is arbitrary
// Problem: Resolved reports may show as pending for up to 24 hours
// Fix: Subscribe to realtime report status changes or use shorter expiry (1hr)

// TODO: [SCALABILITY] 10,000 report cap may be insufficient
// Current: _maxCachedReports = 10000 with LRU eviction
// Consider: For global view, might need geographic partitioning instead
// (e.g., cache by region/grid cell, evict entire regions)

/// Service for caching remote reports locally using encrypted Hive storage.
/// Supports delta sync via timestamps and LRU eviction when cache is full.
class ReportCacheService {
  static const String _boxName = 'cached_reports';
  static const String _metaBoxName = 'cache_metadata';
  static const Duration _cacheExpiry = Duration(hours: 24);
  static const int _maxCachedReports = 10000;

  Box<Map>? _box;
  Box? _metaBox;
  bool _isInitialized = false;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the cache with encrypted storage
  Future<void> initialize() async {
    if (_isInitialized) return;

    final encryptionKey = await SecureStorageService.getOrCreateHiveKey();

    try {
      _box = await Hive.openBox<Map>(
        _boxName,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
      _metaBox = await Hive.openBox(
        _metaBoxName,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
    } catch (e) {
      AppLogger.warning('Migrating cache to encrypted storage: $e');
      await Hive.deleteBoxFromDisk(_boxName);
      await Hive.deleteBoxFromDisk(_metaBoxName);
      _box = await Hive.openBox<Map>(
        _boxName,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
      _metaBox = await Hive.openBox(
        _metaBoxName,
        encryptionCipher: HiveAesCipher(encryptionKey),
      );
    }

    _isInitialized = true;
    AppLogger.info('Report cache initialized with ${_box!.length} items');
  }

  /// Get last sync timestamp for delta sync
  DateTime? getLastSyncTime() {
    if (_metaBox == null) return null;
    final timestamp = _metaBox!.get('last_sync_time');
    if (timestamp == null) return null;
    try {
      return DateTime.parse(timestamp as String);
    } catch (e) {
      return null;
    }
  }

  /// Update last sync timestamp
  Future<void> setLastSyncTime(DateTime time) async {
    await _metaBox?.put('last_sync_time', time.toUtc().toIso8601String());
  }

  /// Get last synced bounds (to know if we need to fetch a new area)
  Map<String, double>? getLastSyncedBounds() {
    if (_metaBox == null) return null;
    final boundsJson = _metaBox!.get('last_synced_bounds');
    if (boundsJson == null) return null;
    try {
      final decoded = jsonDecode(boundsJson as String) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (e) {
      return null;
    }
  }

  /// Store last synced bounds
  Future<void> setLastSyncedBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
    final bounds = {
      'minLat': minLat,
      'maxLat': maxLat,
      'minLng': minLng,
      'maxLng': maxLng,
    };
    await _metaBox?.put('last_synced_bounds', jsonEncode(bounds));
  }

  /// Check if the given bounds are within the last synced bounds
  bool areBoundsInCache({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) {
    final lastBounds = getLastSyncedBounds();
    if (lastBounds == null) return false;

    return minLat >= lastBounds['minLat']! &&
        maxLat <= lastBounds['maxLat']! &&
        minLng >= lastBounds['minLng']! &&
        maxLng <= lastBounds['maxLng']!;
  }

  /// Cache multiple reports from API response
  Future<void> cacheReports(List<Map<String, dynamic>> reports) async {
    if (_box == null || reports.isEmpty) return;

    final now = DateTime.now().toUtc().toIso8601String();

    for (final report in reports) {
      final id = report['id'] as String?;
      if (id == null) continue;

      // Parse location from POINT(lng lat) format
      double? lat, lng;
      final location = report['location'] as String?;
      if (location != null && location.startsWith('POINT')) {
        final coords =
            location.replaceAll('POINT(', '').replaceAll(')', '').split(' ');
        if (coords.length == 2) {
          lng = double.tryParse(coords[0]);
          lat = double.tryParse(coords[1]);
        }
      }

      // Store with parsed coordinates for efficient bounds filtering
      final cacheEntry = Map<String, dynamic>.from(report);
      cacheEntry['_cached_at'] = now;
      cacheEntry['_lat'] = lat;
      cacheEntry['_lng'] = lng;

      await _box!.put(id, cacheEntry);
    }

    // Prune if over limit
    if (_box!.length > _maxCachedReports) {
      await _pruneOldestEntries();
    }

    AppLogger.info('Cached ${reports.length} reports, total: ${_box!.length}');
  }

  /// Get cached reports within bounds
  List<Map<String, dynamic>> getReportsInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) {
    if (_box == null) return [];

    final results = <Map<String, dynamic>>[];

    for (final entry in _box!.values) {
      final lat = entry['_lat'] as double?;
      final lng = entry['_lng'] as double?;

      if (lat == null || lng == null) continue;

      if (lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng) {
        // Return a copy without internal cache fields
        final report = Map<String, dynamic>.from(entry);
        report.remove('_cached_at');
        report.remove('_lat');
        report.remove('_lng');
        results.add(report);
      }
    }

    // Sort by reported_at descending
    results.sort((a, b) {
      final aTime = a['reported_at'] as String?;
      final bTime = b['reported_at'] as String?;
      if (aTime == null || bTime == null) return 0;
      return bTime.compareTo(aTime);
    });

    return results;
  }

  /// Update a single cached report (e.g., when marked as recovered)
  Future<void> updateCachedReport(
      String id, Map<String, dynamic> updates) async {
    if (_box == null) return;

    final existing = _box!.get(id);
    if (existing != null) {
      final updated = Map<String, dynamic>.from(existing);
      updated.addAll(updates);
      updated['_cached_at'] = DateTime.now().toUtc().toIso8601String();
      await _box!.put(id, updated);
    }
  }

  /// Remove a report from cache
  Future<void> removeCachedReport(String id) async {
    await _box?.delete(id);
  }

  /// Check if cache is stale (older than expiry duration)
  bool isCacheStale() {
    final lastSync = getLastSyncTime();
    if (lastSync == null) return true;
    return DateTime.now().toUtc().difference(lastSync) > _cacheExpiry;
  }

  /// Get count of cached reports
  int get cachedCount => _box?.length ?? 0;

  /// Clear all cached data
  Future<void> clearCache() async {
    await _box?.clear();
    await _metaBox?.clear();
    AppLogger.info('Report cache cleared');
  }

  /// Prune oldest entries when cache is full using LRU eviction
  Future<void> _pruneOldestEntries() async {
    if (_box == null) return;

    final entries = _box!.toMap().entries.toList();

    // Sort by cached_at timestamp (oldest first)
    entries.sort((a, b) {
      final aTime = a.value['_cached_at'] as String? ?? '';
      final bTime = b.value['_cached_at'] as String? ?? '';
      return aTime.compareTo(bTime);
    });

    // Remove oldest 20%
    final toRemove = (entries.length * 0.2).ceil();
    for (var i = 0; i < toRemove && i < entries.length; i++) {
      await _box!.delete(entries[i].key);
    }

    AppLogger.info('Pruned $toRemove old cache entries');
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _box?.close();
    await _metaBox?.close();
    _isInitialized = false;
  }
}
