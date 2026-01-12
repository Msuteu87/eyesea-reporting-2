import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/pending_report.dart';
import '../../domain/entities/report.dart';
import '../../data/datasources/report_data_source.dart';
import 'connectivity_service.dart';

/// Service to manage offline report queue.
/// Stores reports locally in Hive and syncs to Supabase when online.
class ReportQueueService {
  static const String _boxName = 'pending_reports';
  static const int _maxRetries = 3;

  final ReportDataSource _dataSource;
  final ConnectivityService _connectivityService;

  Box<PendingReport>? _box;
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;
  bool _authRequiredForSync = false;

  final _pendingCountController = StreamController<int>.broadcast();

  ReportQueueService(this._dataSource, this._connectivityService);

  /// Stream of pending report count for UI badges
  Stream<int> get pendingCountStream => _pendingCountController.stream;

  /// Get current pending count
  int get pendingCount =>
      _box?.values.where((r) => r.syncStatus != SyncStatus.synced).length ?? 0;

  /// True if sync was paused due to auth expiration - UI can prompt re-login
  bool get authRequiredForSync => _authRequiredForSync;

  /// Initialize Hive box and start sync listener
  Future<void> initialize() async {
    // Register adapter if not already registered
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PendingReportAdapter());
    }

    _box = await Hive.openBox<PendingReport>(_boxName);
    debugPrint('📦 Report queue initialized with ${_box!.length} items');

    // Listen for connectivity changes
    _connectivitySubscription =
        _connectivityService.onConnectivityChanged.listen((isOnline) {
      if (isOnline) {
        debugPrint('📶 Back online - triggering sync');
        syncPendingReports();
      }
    });

    // Notify initial count
    _notifyPendingCount();

    // Try initial sync if online
    if (_connectivityService.isOnline) {
      syncPendingReports();
    }
  }

  /// Add a new report to the queue with full gamification and AI analysis data
  Future<PendingReport> addToQueue({
    required String imagePath,
    required PollutionType pollutionType,
    required int severity,
    String? notes,
    required double latitude,
    required double longitude,
    String? city,
    String? country,
    // NEW: Gamification and fraud detection fields
    required Map<PollutionType, int> pollutionCounts,
    required double totalWeightKg,
    required int xpEarned,
    required bool isFlagged,
    required double fraudScore,
    required List<String> fraudWarnings,
    required List<String> sceneLabels,
    required Map<PollutionType, int> aiBaselineCounts,
    required int peopleDetected,
  }) async {
    // Convert PollutionType maps to string keys for JSON serialization
    final pollutionCountsJson = jsonEncode(
      pollutionCounts.map((k, v) => MapEntry(k.name, v)),
    );
    final aiBaselineCountsJson = jsonEncode(
      aiBaselineCounts.map((k, v) => MapEntry(k.name, v)),
    );
    final fraudWarningsJson = jsonEncode(fraudWarnings);
    final sceneLabelsJson = jsonEncode(sceneLabels);

    final report = PendingReport(
      id: const Uuid().v4(),
      imagePath: imagePath,
      pollutionType: pollutionType.name,
      severity: severity,
      notes: notes,
      latitude: latitude,
      longitude: longitude,
      createdAt: DateTime.now(),
      city: city,
      country: country,
      // NEW fields
      pollutionCountsJson: pollutionCountsJson,
      totalWeightKg: totalWeightKg,
      xpEarned: xpEarned,
      isFlagged: isFlagged,
      fraudScore: fraudScore,
      fraudWarningsJson: fraudWarningsJson,
      sceneLabelsJson: sceneLabelsJson,
      aiBaselineCountsJson: aiBaselineCountsJson,
      peopleDetected: peopleDetected,
    );

    await _box!.put(report.id, report);
    debugPrint('📥 Added report to queue: ${report.id}');
    debugPrint('   XP: ${report.xpEarned}, Weight: ${report.totalWeightKg}kg');
    debugPrint('   Flagged: ${report.isFlagged}, Fraud score: ${report.fraudScore}');
    _notifyPendingCount();

    // Try to sync immediately if online
    if (_connectivityService.isOnline) {
      syncPendingReports();
    }

    return report;
  }

  /// Get all pending (unsynced) reports
  List<PendingReport> getPendingReports() {
    return _box?.values
            .where((r) => r.syncStatus != SyncStatus.synced)
            .toList() ??
        [];
  }

  /// Sync all pending reports to Supabase
  Future<void> syncPendingReports() async {
    if (_isSyncing || _box == null) return;
    _isSyncing = true;

    debugPrint('🔄 Starting sync of $pendingCount pending reports');

    // Best practice: Use currentSession + refreshSession to validate auth
    // Supabase Flutter client persists session locally and handles refresh
    try {
      final session = Supabase.instance.client.auth.currentSession;

      if (session == null) {
        // No valid session - user needs to re-authenticate
        // DON'T sign out automatically, just pause sync
        debugPrint('⏸️ No valid session. Reports preserved for after login.');
        _isSyncing = false;
        _authRequiredForSync = true; // Flag for UI to show re-auth prompt
        return;
      }

      // Check if session is expired or expiring soon
      final expiresAt =
          DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
      if (expiresAt.isBefore(DateTime.now().add(const Duration(minutes: 5)))) {
        debugPrint('🔑 Token expiring soon, attempting refresh...');
        final refreshResponse =
            await Supabase.instance.client.auth.refreshSession();
        if (refreshResponse.session == null) {
          debugPrint(
              '⏸️ Token refresh returned no session. Reports preserved.');
          _isSyncing = false;
          _authRequiredForSync = true;
          return;
        }
        debugPrint('🔑 Token refreshed successfully');
      }

      debugPrint('🔑 Session valid, proceeding with sync');
      _authRequiredForSync = false;
    } catch (e) {
      // Token refresh failed - could be network error or truly expired
      // DON'T sign out, preserve reports
      debugPrint('⚠️ Session check failed: $e');
      debugPrint('⏸️ Reports preserved - will retry when back online');
      _isSyncing = false;
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      debugPrint('⏸️ Sync paused - no user. Reports preserved.');
      _isSyncing = false;
      return;
    }

    final pending = getPendingReports();

    for (final report in pending) {
      if (report.syncStatus == SyncStatus.syncing) continue;
      if (report.retryCount >= _maxRetries) {
        debugPrint('⚠️ Report ${report.id} exceeded max retries, skipping');
        continue;
      }

      try {
        // Mark as syncing
        report.syncStatus = SyncStatus.syncing;
        await report.save();

        // Re-check user (might have changed during loop)
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser == null) {
          throw const AuthException('Session expired');
        }

        // Create report in database with all gamification/fraud fields
        final reportData = {
          'user_id': currentUser.id,
          'pollution_type': report.pollutionType,
          'severity': report.severity,
          'status': 'pending',
          'location': 'POINT(${report.longitude} ${report.latitude})',
          'notes': report.notes,
          'is_anonymous': false,
          'city': report.city,
          'country': report.country,
          // NEW: Gamification and fraud detection fields
          'pollution_counts': report.pollutionCounts,
          'total_weight_kg': report.totalWeightKg,
          'xp_earned': report.xpEarned,
          'is_flagged': report.isFlagged,
          'fraud_score': report.fraudScore,
          'fraud_warnings': report.fraudWarnings,
        };

        final createdReport = await _dataSource.createReport(reportData);
        final reportId = createdReport['id'] as String;

        // Upload image
        final imageFile = File(report.imagePath);
        if (imageFile.existsSync()) {
          final publicUrl = await _dataSource.uploadReportImage(
            user.id,
            reportId,
            imageFile,
          );

          // Create image record
          await _dataSource.createReportImageRecord(reportId, publicUrl, true);
        }

        // Create AI analysis record
        await _dataSource.createAIAnalysisRecord(
          reportId: reportId,
          sceneLabels: report.sceneLabels,
          pollutionTypeCounts: report.aiBaselineCounts,
          peopleCount: report.peopleDetected,
        );

        // Mark as synced and remove from queue
        report.syncStatus = SyncStatus.synced;
        await _box!.delete(report.id);

        // Clean up local image file to free storage
        try {
          if (imageFile.existsSync()) {
            imageFile.deleteSync();
            debugPrint('🗑️ Deleted local image: ${report.imagePath}');
          }
        } catch (e) {
          debugPrint('⚠️ Failed to delete local image: $e');
        }

        debugPrint('✅ Synced report ${report.id} (+${report.xpEarned} XP)');
      } on AuthException catch (e) {
        // Auth errors shouldn't count as retries - user just needs to re-login
        debugPrint('🔐 Auth error for report ${report.id}: $e');
        debugPrint('⏸️ Report preserved - will sync after re-login');
        report.syncStatus = SyncStatus.pending; // Reset to pending, not failed
        report.errorMessage = 'Please log in to sync';
        await report.save();
        // Stop trying to sync more - user needs to re-authenticate
        break;
      } catch (e) {
        debugPrint('❌ Failed to sync report ${report.id}: $e');
        report.syncStatus = SyncStatus.failed;
        report.retryCount++;
        report.errorMessage = e.toString();
        await report.save();
      }
    }

    _isSyncing = false;
    _notifyPendingCount();
    debugPrint('🔄 Sync complete. $pendingCount reports still pending');
  }

  /// Remove a report from the queue
  Future<void> removeFromQueue(String id) async {
    await _box?.delete(id);
    _notifyPendingCount();
  }

  /// Clear all synced reports
  Future<void> clearSynced() async {
    final synced =
        _box?.values.where((r) => r.syncStatus == SyncStatus.synced).toList() ??
            [];

    for (final report in synced) {
      await _box?.delete(report.id);
    }
    _notifyPendingCount();
  }

  void _notifyPendingCount() {
    _pendingCountController.add(pendingCount);
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _pendingCountController.close();
  }
}
