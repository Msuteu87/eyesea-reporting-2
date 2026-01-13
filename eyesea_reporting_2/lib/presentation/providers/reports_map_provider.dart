import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/report_queue_service.dart';
import '../../data/datasources/report_data_source.dart';
import '../../domain/entities/pending_report.dart';
import '../../domain/entities/report.dart';

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

    debugPrint(
        '📍 fromPending: id=${report.id}, weight=${report.totalWeightKg}, items=$totalItems, counts=$counts');

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
    );
  }

  /// Create from a synced (remote) report
  factory MapMarkerData.fromEntity(ReportEntity report) {
    final totalItems =
        report.pollutionCounts.values.fold(0, (sum, count) => sum + count);

    debugPrint(
        '📍 fromEntity: id=${report.id}, weight=${report.totalWeightKg}, items=$totalItems, counts=${report.pollutionCounts}');

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
}

/// Provider that manages map markers for pollution reports.
/// Combines local pending reports (offline) with remote synced reports (online).
class ReportsMapProvider extends ChangeNotifier {
  final ReportDataSource _dataSource;
  final ReportQueueService _queueService;
  final ConnectivityService _connectivityService;

  List<MapMarkerData> _markers = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _queueSubscription;
  StreamSubscription? _connectivitySubscription;

  /// Filter for visible report statuses (default: show all active)
  Set<ReportStatus> _visibleStatuses = {
    ReportStatus.pending,
    ReportStatus.verified,
    ReportStatus.resolved,
  };

  /// Filter to show only current user's reports (default: true for performance)
  bool _showOnlyMyReports = true;

  /// Current user ID for filtering "My Reports"
  String? _currentUserId;

  ReportsMapProvider(
    this._dataSource,
    this._queueService,
    this._connectivityService,
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
    // Reload markers when user changes
    loadMarkers();
  }

  /// Get markers filtered by visible statuses and optionally by user
  List<MapMarkerData> get filteredMarkers {
    var filtered = _markers.where((m) => _visibleStatuses.contains(m.status));

    // If showOnlyMyReports is enabled and we have a user ID, filter by user
    if (_showOnlyMyReports && _currentUserId != null) {
      filtered = filtered.where((m) => m.userId == _currentUserId);
    }

    return filtered.toList();
  }

  /// Update the visible status filter
  void setVisibleStatuses(Set<ReportStatus> statuses) {
    _visibleStatuses = statuses;
    notifyListeners();
  }

  /// Toggle showing only user's reports vs all reports
  void setShowOnlyMyReports(bool value) {
    _showOnlyMyReports = value;
    notifyListeners();
  }

  void _init() {
    // Listen for pending report changes (new submissions, syncs)
    _queueSubscription = _queueService.pendingCountStream.listen((_) {
      debugPrint('📍 Pending count changed, reloading markers');
      loadMarkers();
    });

    // Listen for connectivity changes to reload remote reports
    _connectivitySubscription =
        _connectivityService.onConnectivityChanged.listen((isOnline) {
      if (isOnline) {
        debugPrint('📍 Back online, fetching remote reports');
        loadMarkers();
      }
    });
  }

  /// Load markers from both local queue and remote database
  /// If [bounds] is provided, only fetch reports within that bounding box
  Future<void> loadMarkers({
    double? minLat,
    double? maxLat,
    double? minLng,
    double? maxLng,
  }) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final combinedMarkers = <MapMarkerData>[];
      final seenIds = <String>{};

      // 1. Always load pending (local) reports first - works offline
      final pendingReports = _queueService.getPendingReports();
      debugPrint('📍 Found ${pendingReports.length} pending local reports');

      for (final pending in pendingReports) {
        if (pending.syncStatus != SyncStatus.synced) {
          // If bounds provided, filter local reports too
          if (minLat != null &&
              maxLat != null &&
              minLng != null &&
              maxLng != null) {
            if (pending.latitude < minLat ||
                pending.latitude > maxLat ||
                pending.longitude < minLng ||
                pending.longitude > maxLng) {
              continue;
            }
          }
          combinedMarkers.add(MapMarkerData.fromPending(pending, currentUserId: _currentUserId));
          seenIds.add(pending.id);
        }
      }

      // 2. If online, fetch remote reports from Supabase
      if (_connectivityService.isOnline) {
        try {
          List<Map<String, dynamic>> remoteData;

          // Use bounds-aware fetch if bounds provided
          if (minLat != null &&
              maxLat != null &&
              minLng != null &&
              maxLng != null) {
            remoteData = await _dataSource.fetchReportsInBounds(
              minLat: minLat,
              maxLat: maxLat,
              minLng: minLng,
              maxLng: maxLng,
            );
            debugPrint('📍 Fetched ${remoteData.length} reports in bounds');
          } else {
            remoteData = await _dataSource.fetchReports();
            debugPrint(
                '📍 Fetched ${remoteData.length} remote reports (no bounds)');
          }

          for (final json in remoteData) {
            final report = ReportEntity.fromJson(json);
            // Skip if we already have this as a pending report
            if (!seenIds.contains(report.id)) {
              combinedMarkers.add(MapMarkerData.fromEntity(report));
              seenIds.add(report.id);
            }
          }
        } catch (e) {
          debugPrint('⚠️ Failed to fetch remote reports: $e');
          // Continue with local reports only
        }
      } else {
        debugPrint('📍 Offline - showing only local pending reports');
      }

      // Sort by creation date (newest first)
      combinedMarkers.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _markers = combinedMarkers;
      debugPrint('📍 Total markers: ${_markers.length}');
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error loading markers: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Force refresh markers (pull-to-refresh or manual)
  Future<void> refresh() async {
    _markers = [];
    notifyListeners();
    await loadMarkers();
  }

  /// Mark a report as recovered (resolved)
  Future<void> markAsRecovered(String reportId) async {
    try {
      await _dataSource.markAsRecovered(reportId);
      // Update the local marker status immediately
      final index = _markers.indexWhere((m) => m.id == reportId);
      if (index != -1) {
        final oldMarker = _markers[index];
        _markers[index] = MapMarkerData(
          id: oldMarker.id,
          userId: oldMarker.userId,
          latitude: oldMarker.latitude,
          longitude: oldMarker.longitude,
          pollutionType: oldMarker.pollutionType,
          severity: oldMarker.severity,
          isPending: oldMarker.isPending,
          createdAt: oldMarker.createdAt,
          imageUrl: oldMarker.imageUrl,
          totalWeightKg: oldMarker.totalWeightKg,
          totalItems: oldMarker.totalItems,
          pollutionCounts: oldMarker.pollutionCounts,
          status: ReportStatus.resolved,
        );
        notifyListeners();
      }
      debugPrint('✅ Report $reportId marked as recovered');
    } catch (e) {
      debugPrint('❌ Error marking report as recovered: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _queueSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
