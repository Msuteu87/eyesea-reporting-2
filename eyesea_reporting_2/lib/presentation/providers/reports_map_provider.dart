// TODO: [MAINTAINABILITY] This file is 594 lines - provider does too much.
// Split into: ReportsDataProvider, ReportsFilterProvider, ReportsMarkerProvider
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/report_cache_service.dart';
import '../../core/services/report_queue_service.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/pending_report.dart';
import '../../domain/entities/report.dart';
import '../../domain/repositories/report_repository.dart';

/// Data class for map markers combining local and remote reports
class MapMarkerData {
  final String id;
  final String? userId; // Reporter's user ID for filtering
  final double latitude;
  final double longitude;
  final PollutionType pollutionType;
  final int severity;
  final bool isPending; // true = local/offline, false = synced from server
  final DateTime createdAt;
  final String? imageUrl;
  final double? totalWeightKg;
  final int totalItems;
  final Map<PollutionType, int> pollutionCounts;
  final ReportStatus status; // For marker color: resolved = green
  final String? city;
  final String? country;

  MapMarkerData({
    required this.id,
    this.userId,
    required this.latitude,
    required this.longitude,
    required this.pollutionType,
    required this.severity,
    required this.isPending,
    required this.createdAt,
    this.imageUrl,
    this.totalWeightKg,
    this.totalItems = 0,
    this.pollutionCounts = const {},
    this.status = ReportStatus.pending,
    this.city,
    this.country,
  });

  /// Create from a pending (local) report
  /// [currentUserId] should be passed since pending reports are always from the current user
  factory MapMarkerData.fromPending(PendingReport report, {String? currentUserId}) {
    // Convert String keys to PollutionType keys
    final counts = <PollutionType, int>{};
    for (final entry in report.pollutionCounts.entries) {
      final type = _parsePollutionType(entry.key);
      counts[type] = (counts[type] ?? 0) + entry.value;
    }

    // Calculate total items
    final totalItems = counts.values.fold(0, (sum, count) => sum + count);

    AppLogger.debug('fromPending: id=${report.id}, weight=${report.totalWeightKg}, items=$totalItems, counts=$counts');

    return MapMarkerData(
      id: report.id,
      userId: currentUserId, // Pending reports are from current user
      latitude: report.latitude,
      longitude: report.longitude,
      pollutionType: _parsePollutionType(report.pollutionType),
      severity: report.severity,
      isPending: true,
      createdAt: report.createdAt,
      imageUrl: null, // Local pending reports may have local path only
      totalWeightKg: report.totalWeightKg > 0 ? report.totalWeightKg : null,
      totalItems: totalItems,
      pollutionCounts: counts,
      city: report.city,
      country: report.country,
    );
  }

  /// Create from a synced (remote) report
  factory MapMarkerData.fromEntity(ReportEntity report) {
    final totalItems =
        report.pollutionCounts.values.fold(0, (sum, count) => sum + count);

    AppLogger.debug('fromEntity: id=${report.id}, weight=${report.totalWeightKg}, items=$totalItems, counts=${report.pollutionCounts}');

    return MapMarkerData(
      id: report.id,
      userId: report.userId, // From the report entity
      latitude: report.location.coordinates.lat.toDouble(),
      longitude: report.location.coordinates.lng.toDouble(),
      pollutionType: report.pollutionType,
      severity: report.severity,
      isPending: false,
      createdAt: report.reportedAt,
      imageUrl: report.imageUrls.isNotEmpty ? report.imageUrls.first : null,
      totalWeightKg: report.totalWeightKg,
      totalItems: totalItems,
      pollutionCounts: report.pollutionCounts,
      status: report.status,
      city: report.city,
      country: report.country,
    );
  }

  static PollutionType _parsePollutionType(String type) {
    switch (type) {
      case 'plastic':
        return PollutionType.plastic;
      case 'oil':
        return PollutionType.oil;
      case 'debris':
        return PollutionType.debris;
      case 'sewage':
        return PollutionType.sewage;
      case 'fishingGear':
      case 'fishing_gear':
        return PollutionType.fishingGear;
      case 'container':
        return PollutionType.container;
      default:
        return PollutionType.other;
    }
  }

  /// Creates a copy of this marker with the given fields replaced
  MapMarkerData copyWith({
    String? id,
    String? userId,
    double? latitude,
    double? longitude,
    PollutionType? pollutionType,
    int? severity,
    bool? isPending,
    DateTime? createdAt,
    String? imageUrl,
    double? totalWeightKg,
    int? totalItems,
    Map<PollutionType, int>? pollutionCounts,
    ReportStatus? status,
    String? city,
    String? country,
  }) {
    return MapMarkerData(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      pollutionType: pollutionType ?? this.pollutionType,
      severity: severity ?? this.severity,
      isPending: isPending ?? this.isPending,
      createdAt: createdAt ?? this.createdAt,
      imageUrl: imageUrl ?? this.imageUrl,
      totalWeightKg: totalWeightKg ?? this.totalWeightKg,
      totalItems: totalItems ?? this.totalItems,
      pollutionCounts: pollutionCounts ?? this.pollutionCounts,
      status: status ?? this.status,
      city: city ?? this.city,
      country: country ?? this.country,
    );
  }
}

/// Provider that manages map markers for pollution reports.
/// Combines local pending reports (offline) with remote synced reports (online).
/// Supports server-side clustering, local caching, and delta sync.
class ReportsMapProvider extends ChangeNotifier {
  final ReportRepository _repository;
  final ReportQueueService _queueService;
  final ConnectivityService _connectivityService;
  final ReportCacheService _cacheService;

  List<MapMarkerData> _markers = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _queueSubscription;
  StreamSubscription? _connectivitySubscription;

  // Debounce timers to prevent rapid-fire updates
  Timer? _loadDebounce;
  Timer? _reconnectDebounce;
  static const _debounceMs = 100;

  // Exponential backoff for reconnection (thundering herd prevention)
  int _reconnectAttempts = 0;
  static const _baseBackoffMs = 1000;
  static const _maxBackoffMs = 30000;
  final _random = Random();

  // Track current viewport for incremental loading
  double? _lastMinLat, _lastMaxLat, _lastMinLng, _lastMaxLng;
  int _lastZoomLevel = 10;

  /// Filter for visible report statuses (default: show all active)
  Set<ReportStatus> _visibleStatuses = {
    ReportStatus.pending,
    ReportStatus.verified,
    ReportStatus.resolved,
  };

  /// Filter to show only current user's reports (default: false to show all reports)
  bool _showOnlyMyReports = false;

  /// Current user ID for filtering "My Reports"
  String? _currentUserId;

  // Cached filtered markers for performance
  List<MapMarkerData>? _cachedFilteredMarkers;
  Set<ReportStatus>? _lastFilteredStatuses;
  bool? _lastShowOnlyMyReports;
  String? _lastFilteredUserId;
  int _lastMarkersLength = 0;

  ReportsMapProvider(
    this._repository,
    this._queueService,
    this._connectivityService,
    this._cacheService,
  ) {
    _init();
  }

  List<MapMarkerData> get markers => _markers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Set<ReportStatus> get visibleStatuses => _visibleStatuses;
  bool get showOnlyMyReports => _showOnlyMyReports;
  String? get currentUserId => _currentUserId;

  /// Set the current user ID for filtering
  void setCurrentUserId(String? userId) {
    _currentUserId = userId;
    // Reload markers when user changes (if we have a viewport)
    _reloadCurrentViewport();
  }

  /// Get markers filtered by visible statuses and optionally by user.
  /// Results are cached and only recomputed when filter parameters change.
  List<MapMarkerData> get filteredMarkers {
    // Check if cache is valid
    final cacheValid = _cachedFilteredMarkers != null &&
        _lastFilteredStatuses != null &&
        _setEquals(_lastFilteredStatuses!, _visibleStatuses) &&
        _lastShowOnlyMyReports == _showOnlyMyReports &&
        _lastFilteredUserId == _currentUserId &&
        _lastMarkersLength == _markers.length;

    if (cacheValid) {
      return _cachedFilteredMarkers!;
    }

    // Recompute filtered markers
    var filtered = _markers.where((m) => _visibleStatuses.contains(m.status));

    // If showOnlyMyReports is enabled and we have a user ID, filter by user
    if (_showOnlyMyReports && _currentUserId != null) {
      filtered = filtered.where((m) => m.userId == _currentUserId);
    }

    // Update cache
    _cachedFilteredMarkers = filtered.toList();
    _lastFilteredStatuses = Set.from(_visibleStatuses);
    _lastShowOnlyMyReports = _showOnlyMyReports;
    _lastFilteredUserId = _currentUserId;
    _lastMarkersLength = _markers.length;

    return _cachedFilteredMarkers!;
  }

  /// Helper to compare two sets for equality
  bool _setEquals<T>(Set<T> a, Set<T> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  /// Invalidates the filtered markers cache
  void _invalidateFilterCache() {
    _cachedFilteredMarkers = null;
  }

  /// Update the visible status filter
  void setVisibleStatuses(Set<ReportStatus> statuses) {
    _visibleStatuses = statuses;
    _invalidateFilterCache();
    notifyListeners();
  }

  /// Toggle showing only user's reports vs all reports
  void setShowOnlyMyReports(bool value) {
    _showOnlyMyReports = value;
    _invalidateFilterCache();
    notifyListeners();
  }

  void _init() {
    // Listen for pending report changes (new submissions, syncs) with debouncing
    _queueSubscription = _queueService.pendingCountStream.listen((_) {
      _loadDebounce?.cancel();
      _loadDebounce = Timer(const Duration(milliseconds: _debounceMs), () {
        AppLogger.info('Pending count changed, reloading markers');
        _reloadCurrentViewport();
      });
    });

    // Listen for connectivity changes with exponential backoff (thundering herd prevention)
    _connectivitySubscription =
        _connectivityService.onConnectivityChanged.listen((isOnline) {
      if (isOnline) {
        _reconnectDebounce?.cancel();
        final backoffMs = _calculateBackoff();
        AppLogger.info('Back online, scheduling reload in ${backoffMs}ms');
        _reconnectDebounce = Timer(Duration(milliseconds: backoffMs), () {
          if (_connectivityService.isOnline) {
            AppLogger.info('Executing delayed reload after reconnection');
            _reconnectAttempts = 0; // Reset on successful online
            _reloadCurrentViewport();
          }
        });
      } else {
        _reconnectAttempts++;
      }
    });
  }

  /// Calculate exponential backoff with jitter for reconnection
  int _calculateBackoff() {
    // Exponential backoff: 1s, 2s, 4s, 8s... up to 30s
    final baseDelay = (_baseBackoffMs * (1 << _reconnectAttempts.clamp(0, 5)))
        .clamp(0, _maxBackoffMs);
    // Add random jitter (0-30% of base delay)
    final jitter = (baseDelay * 0.3 * _random.nextDouble()).toInt();
    return baseDelay + jitter;
  }

  /// Reload markers for the current viewport (if known)
  void _reloadCurrentViewport() {
    if (_lastMinLat != null &&
        _lastMaxLat != null &&
        _lastMinLng != null &&
        _lastMaxLng != null) {
      loadMarkers(
        minLat: _lastMinLat!,
        maxLat: _lastMaxLat!,
        minLng: _lastMinLng!,
        maxLng: _lastMaxLng!,
        zoomLevel: _lastZoomLevel,
      );
    }
  }

  /// Load markers from both local queue and remote database.
  /// Bounds are required for viewport-based loading.
  /// [zoomLevel] determines whether to use server-side clustering (zoom < 14).
  Future<void> loadMarkers({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    int zoomLevel = 10,
  }) async {
    AppLogger.info('[ReportsMapProvider] loadMarkers called with bounds: ($minLat,$minLng) to ($maxLat,$maxLng), zoom: $zoomLevel');

    if (_isLoading) {
      AppLogger.debug('[ReportsMapProvider] Already loading, skipping');
      return;
    }

    // Store viewport for later reloads
    _lastMinLat = minLat;
    _lastMaxLat = maxLat;
    _lastMinLng = minLng;
    _lastMaxLng = maxLng;
    _lastZoomLevel = zoomLevel;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final combinedMarkers = <MapMarkerData>[];
      final seenIds = <String>{};

      // 1. Always load pending (local) reports first - works offline
      final pendingReports = _queueService.getPendingReports();
      AppLogger.info('Found ${pendingReports.length} pending local reports');

      for (final pending in pendingReports) {
        if (pending.syncStatus != SyncStatus.synced) {
          // Filter by bounds
          if (pending.latitude < minLat ||
              pending.latitude > maxLat ||
              pending.longitude < minLng ||
              pending.longitude > maxLng) {
            continue;
          }
          combinedMarkers.add(MapMarkerData.fromPending(pending, currentUserId: _currentUserId));
          seenIds.add(pending.id);
        }
      }

      // 2. Show cached data immediately (for instant UI feedback)
      if (_cacheService.isInitialized) {
        final cachedReports = _cacheService.getReportsInBounds(
          minLat: minLat,
          maxLat: maxLat,
          minLng: minLng,
          maxLng: maxLng,
        );

        if (cachedReports.isNotEmpty) {
          AppLogger.info('Showing ${cachedReports.length} cached reports');
          for (final json in cachedReports) {
            final report = ReportEntity.fromJson(json);
            if (!seenIds.contains(report.id)) {
              combinedMarkers.add(MapMarkerData.fromEntity(report));
              seenIds.add(report.id);
            }
          }
          // Show cached data immediately
          combinedMarkers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _markers = List.from(combinedMarkers);
          _invalidateFilterCache();
          notifyListeners();
        }
      }

      // 3. If online, fetch fresh data from Supabase
      AppLogger.info('[ReportsMapProvider] Connectivity: isOnline=${_connectivityService.isOnline}');
      if (_connectivityService.isOnline) {
        try {
          // Use delta sync ONLY if ALL conditions are met:
          // 1. Cache is initialized
          // 2. Cache is not stale (within 24 hours)
          // 3. Current viewport is WITHIN the last synced bounds
          // Otherwise, do a full refresh to ensure we have all reports
          DateTime? lastSync;
          if (_cacheService.isInitialized && !_cacheService.isCacheStale()) {
            final cachedLastSync = _cacheService.getLastSyncTime();
            if (cachedLastSync != null) {
              final timeSinceSync = DateTime.now().difference(cachedLastSync);

              // Check if current viewport is within last synced bounds
              final boundsInCache = _cacheService.areBoundsInCache(
                minLat: minLat,
                maxLat: maxLat,
                minLng: minLng,
                maxLng: maxLng,
              );

              if (timeSinceSync.inHours < 24 && boundsInCache) {
                // All conditions met - use delta sync
                lastSync = cachedLastSync;
                AppLogger.debug('Using delta sync (cache age: ${timeSinceSync.inHours}h)');
              } else if (timeSinceSync.inHours >= 24) {
                // Cache too old, clear and do full refresh
                AppLogger.info('Cache too old (${timeSinceSync.inHours}h), clearing for full refresh');
                await _cacheService.clearCache();
              }
              // else: Viewport outside cached bounds - do full refresh for this area
            }
          }

          final remoteData = await _repository.fetchReportsInBounds(
            minLat: minLat,
            maxLat: maxLat,
            minLng: minLng,
            maxLng: maxLng,
            updatedSince: lastSync,
          );
          AppLogger.info('Fetched ${remoteData.length} reports from server (delta: ${lastSync != null})');

          // Update cache with new data
          if (_cacheService.isInitialized && remoteData.isNotEmpty) {
            await _cacheService.cacheReports(remoteData);
            await _cacheService.setLastSyncTime(DateTime.now());
            await _cacheService.setLastSyncedBounds(
              minLat: minLat,
              maxLat: maxLat,
              minLng: minLng,
              maxLng: maxLng,
            );
          }

          // If this was a FULL refresh (not delta), replace cached markers with server data
          // This ensures stale cache data doesn't persist
          if (lastSync == null && remoteData.isNotEmpty) {
            // Keep only pending markers, replace all cached with fresh server data
            final pendingMarkers = combinedMarkers.where((m) => m.isPending).toList();
            combinedMarkers.clear();
            seenIds.clear();

            // Re-add pending markers first
            for (final m in pendingMarkers) {
              combinedMarkers.add(m);
              seenIds.add(m.id);
            }

            // Add all server data
            for (final json in remoteData) {
              final report = ReportEntity.fromJson(json);
              if (!seenIds.contains(report.id)) {
                combinedMarkers.add(MapMarkerData.fromEntity(report));
                seenIds.add(report.id);
              }
            }
            AppLogger.info('Full refresh: replaced cached markers with ${remoteData.length} server reports');
          } else {
            // Delta sync: merge new data with existing markers
            for (final json in remoteData) {
              final report = ReportEntity.fromJson(json);
              if (!seenIds.contains(report.id)) {
                combinedMarkers.add(MapMarkerData.fromEntity(report));
                seenIds.add(report.id);
              } else {
                // Update existing marker with fresh data
                final existingIndex = combinedMarkers.indexWhere((m) => m.id == report.id);
                if (existingIndex != -1 && !combinedMarkers[existingIndex].isPending) {
                  combinedMarkers[existingIndex] = MapMarkerData.fromEntity(report);
                }
              }
            }
          }
        } catch (e) {
          AppLogger.warning('Failed to fetch remote reports: $e');
          // Continue with cached/local reports only
        }
      } else {
        AppLogger.info('Offline - showing cached and pending reports');
      }

      // Sort by creation date (newest first)
      combinedMarkers.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _markers = combinedMarkers;
      _invalidateFilterCache();
      AppLogger.info('Total markers: ${_markers.length}');
    } catch (e) {
      _error = e.toString();
      AppLogger.error('Error loading markers: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Force refresh markers (pull-to-refresh or manual)
  /// Clears cache and reloads current viewport
  Future<void> refresh() async {
    _markers = [];
    _invalidateFilterCache();

    // Clear cache to force fresh fetch
    if (_cacheService.isInitialized) {
      await _cacheService.clearCache();
    }

    notifyListeners();
    _reloadCurrentViewport();
  }

  /// Mark a report as recovered (resolved)
  Future<void> markAsRecovered(String reportId) async {
    try {
      await _repository.markAsRecovered(reportId);
      // Update the local marker status immediately
      final index = _markers.indexWhere((m) => m.id == reportId);
      if (index != -1) {
        _markers[index] = _markers[index].copyWith(status: ReportStatus.resolved);
        _invalidateFilterCache();
        notifyListeners();
      }

      // Update cache as well
      if (_cacheService.isInitialized) {
        await _cacheService.updateCachedReport(reportId, {'status': 'resolved'});
      }

      AppLogger.info('Report $reportId marked as recovered');
    } catch (e) {
      AppLogger.error('Error marking report as recovered: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _queueSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _loadDebounce?.cancel();
    _reconnectDebounce?.cancel();
    super.dispose();
  }
}
