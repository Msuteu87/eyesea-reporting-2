import 'package:flutter/foundation.dart';
import '../../domain/entities/badge.dart';
import '../../domain/entities/report.dart';
import '../../domain/repositories/badge_repository.dart';
import '../../domain/repositories/report_repository.dart';
import '../../core/utils/logger.dart';

// TODO: [SCALABILITY] Unbounded list growth in _userReports
// Current: _userReports = [..._userReports, ...newReports] grows indefinitely
// At 5000 users: Power users with 100s of reports will accumulate excessive memory
// Fix: Cap list size (e.g., 50 items max) or implement windowed pagination
// that drops older items when new ones are loaded.

// TODO: [SCALABILITY] Replace offset pagination with cursor-based pagination
// Current: Uses _reportsOffset which gets slower as offset increases
// Fix: Use cursor (last report's createdAt or ID) for keyset pagination
// This is O(1) vs O(n) for offset-based queries

/// Provider for profile page data including badges, stats, and user reports.
class ProfileProvider extends ChangeNotifier {
  final BadgeRepository _badgeRepository;
  final ReportRepository _reportRepository;

  ProfileProvider(this._badgeRepository, this._reportRepository);

  // Badges state
  List<BadgeEntity> _badges = [];
  List<BadgeEntity> get badges => _badges;
  List<BadgeEntity> get earnedBadges => _badges.where((b) => b.isEarned).toList();
  List<BadgeEntity> get lockedBadges => _badges.where((b) => !b.isEarned).toList();

  // User stats state
  UserStats _stats = UserStats.empty;
  UserStats get stats => _stats;

  // User reports state
  List<ReportEntity> _userReports = [];
  List<ReportEntity> get userReports => _userReports;

  String? _selectedStatus;
  String? get selectedStatus => _selectedStatus;

  // Loading states
  bool _isLoadingBadges = false;
  bool get isLoadingBadges => _isLoadingBadges;

  bool _isLoadingStats = false;
  bool get isLoadingStats => _isLoadingStats;

  bool _isLoadingReports = false;
  bool get isLoadingReports => _isLoadingReports;

  bool _hasMoreReports = true;
  bool get hasMoreReports => _hasMoreReports;

  int _reportsOffset = 0;
  static const int _reportsLimit = 20;

  String? _currentUserId;

  /// Initialize profile data for a user.
  Future<void> loadProfileData(String userId, {int streakDays = 0}) async {
    _currentUserId = userId;
    await Future.wait([
      loadBadges(userId),
      loadStats(userId, streakDays: streakDays),
      loadUserReports(userId, refresh: true),
    ]);
  }

  /// Load badges with earned status.
  Future<void> loadBadges(String userId) async {
    _isLoadingBadges = true;
    notifyListeners();

    try {
      _badges = await _badgeRepository.fetchBadgesWithStatus(userId);
    } catch (e) {
      AppLogger.error('Failed to load badges', e);
      _badges = [];
    } finally {
      _isLoadingBadges = false;
      notifyListeners();
    }
  }

  /// Load user stats including rank.
  Future<void> loadStats(String userId, {int streakDays = 0}) async {
    _isLoadingStats = true;
    notifyListeners();

    try {
      _stats = await _badgeRepository.fetchUserRank(userId, streakDays: streakDays);
    } catch (e) {
      AppLogger.error('Failed to load stats', e);
      _stats = UserStats.empty;
    } finally {
      _isLoadingStats = false;
      notifyListeners();
    }
  }

  /// Load user reports with optional status filter.
  Future<void> loadUserReports(
    String userId, {
    String? status,
    bool refresh = false,
  }) async {
    if (refresh) {
      _reportsOffset = 0;
      _hasMoreReports = true;
      _userReports = [];
    }

    if (!_hasMoreReports && !refresh) return;

    _selectedStatus = status;
    _isLoadingReports = true;
    notifyListeners();

    try {
      final response = await _reportRepository.fetchUserReports(
        userId: userId,
        status: status,
        limit: _reportsLimit,
        offset: _reportsOffset,
      );

      final newReports = response.map((json) => ReportEntity.fromJson(json)).toList();

      if (refresh) {
        _userReports = newReports;
      } else {
        _userReports = [..._userReports, ...newReports];
      }

      _hasMoreReports = newReports.length >= _reportsLimit;
      _reportsOffset += newReports.length;
    } catch (e) {
      AppLogger.error('Failed to load user reports', e);
      if (refresh) {
        _userReports = [];
      }
    } finally {
      _isLoadingReports = false;
      notifyListeners();
    }
  }

  /// Load more reports (pagination).
  Future<void> loadMoreReports() async {
    if (_currentUserId == null || _isLoadingReports || !_hasMoreReports) return;
    await loadUserReports(_currentUserId!, status: _selectedStatus);
  }

  /// Filter reports by status.
  Future<void> filterByStatus(String? status) async {
    if (_currentUserId == null) return;
    await loadUserReports(_currentUserId!, status: status, refresh: true);
  }

  /// Get reports filtered by current status.
  List<ReportEntity> get filteredReports {
    if (_selectedStatus == null) return _userReports;
    return _userReports
        .where((r) => r.status.name == _selectedStatus)
        .toList();
  }

  /// Get count of reports by status.
  Map<String, int> get reportCountsByStatus {
    final counts = <String, int>{
      'all': _userReports.length,
      'pending': 0,
      'verified': 0,
      'resolved': 0,
    };

    for (final report in _userReports) {
      final status = report.status.name;
      counts[status] = (counts[status] ?? 0) + 1;
    }

    return counts;
  }

  /// Refresh all profile data.
  Future<void> refresh() async {
    if (_currentUserId == null) return;
    await loadProfileData(_currentUserId!, streakDays: _stats.streakDays);
  }

  /// Clear all data (on logout).
  void clear() {
    _badges = [];
    _stats = UserStats.empty;
    _userReports = [];
    _selectedStatus = null;
    _reportsOffset = 0;
    _hasMoreReports = true;
    _currentUserId = null;
    notifyListeners();
  }
}
