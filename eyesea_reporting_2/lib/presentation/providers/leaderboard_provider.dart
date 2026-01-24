import 'dart:developer';

import 'package:flutter/foundation.dart';

import '../../data/datasources/badge_data_source.dart';
import '../../data/datasources/leaderboard_data_source.dart';
import '../../domain/entities/badge.dart';
import '../../domain/entities/category_rank.dart';
import '../../domain/entities/leaderboard_entry.dart';

/// Provider for managing leaderboard state across Rankings and Awards tabs.
///
/// ## Scalability Note
///
/// Currently loads all leaderboard entries into memory. For leaderboards with
/// 1000+ entries, consider:
/// - Server-side pagination (limit to top 100)
/// - Virtual scrolling with `SliverList.builder`
/// - Lazy loading as user scrolls
///
/// In practice, leaderboards typically only display top 50-100 entries for
/// meaningful competition, so server-side limiting is the recommended approach.
class LeaderboardProvider extends ChangeNotifier {
  final LeaderboardDataSource _leaderboardDataSource;
  final BadgeDataSource _badgeDataSource;

  LeaderboardProvider(this._leaderboardDataSource, this._badgeDataSource);

  // State
  LeaderboardCategory _category = LeaderboardCategory.users;
  TimeFilter _timeFilter = TimeFilter.last30Days;

  List<LeaderboardEntry> _entries = [];
  CategoryRank? _userRank;
  List<BadgeEntity> _badges = [];

  bool _isLoading = false;
  bool _isLoadingBadges = false;
  String? _error;
  String? _currentUserId;

  // Getters
  LeaderboardCategory get category => _category;
  TimeFilter get timeFilter => _timeFilter;
  List<LeaderboardEntry> get entries => _entries;
  CategoryRank? get userRank => _userRank;
  List<BadgeEntity> get badges => _badges;
  List<BadgeEntity> get earnedBadges =>
      _badges.where((b) => b.isEarned).toList();
  List<BadgeEntity> get lockedBadges =>
      _badges.where((b) => !b.isEarned).toList();
  bool get isLoading => _isLoading;
  bool get isLoadingBadges => _isLoadingBadges;
  String? get error => _error;

  /// Top 3 entries for podium display.
  List<LeaderboardEntry> get podiumEntries {
    if (_entries.length < 3) return _entries;
    return _entries.take(3).toList();
  }

  /// Entries below the podium (rank 4+).
  List<LeaderboardEntry> get listEntries {
    if (_entries.length <= 3) return [];
    return _entries.skip(3).toList();
  }

  /// Check if user is part of the current category.
  bool get userInCurrentCategory {
    if (_category == LeaderboardCategory.users) return true;
    return _userRank?.isMember ?? false;
  }

  /// Initialize with user ID.
  void setCurrentUser(String? userId) {
    _currentUserId = userId;
    log('LeaderboardProvider: set current user: $userId');
  }

  /// Change category and reload.
  Future<void> setCategory(LeaderboardCategory category) async {
    if (_category == category) return;
    log('LeaderboardProvider: category changed from $_category to $category');
    _category = category;
    notifyListeners();
    await loadLeaderboard();
  }

  /// Change time filter and reload.
  Future<void> setTimeFilter(TimeFilter filter) async {
    if (_timeFilter == filter) return;
    log('LeaderboardProvider: time filter changed from $_timeFilter to $filter');
    _timeFilter = filter;
    notifyListeners();
    await loadLeaderboard();
  }

  /// Load leaderboard data for current category and time filter.
  Future<void> loadLeaderboard() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      log('LeaderboardProvider: loading $_category leaderboard with $_timeFilter filter');

      // Load leaderboard entries
      _entries = await _leaderboardDataSource.fetchLeaderboard(
        category: _category,
        timeFilter: _timeFilter,
      );

      log('LeaderboardProvider: loaded ${_entries.length} entries');

      // Load user's rank if authenticated
      if (_currentUserId != null) {
        try {
          _userRank = await _leaderboardDataSource.fetchUserCategoryRank(
            userId: _currentUserId!,
            category: _category,
            timeFilter: _timeFilter,
          );
          log('LeaderboardProvider: user rank is ${_userRank?.rank}');
        } catch (e) {
          log('LeaderboardProvider: could not load user rank: $e');
          _userRank = null;
        }
      }
    } catch (e) {
      log('LeaderboardProvider: error loading leaderboard: $e');
      // Show detailed error in debug mode for troubleshooting
      _error = e.toString().contains('function')
          ? 'Database functions not found. Please apply the migration.'
          : 'Failed to load leaderboard';
      _entries = [];
      _userRank = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load badges for current user.
  Future<void> loadBadges() async {
    if (_currentUserId == null) {
      log('LeaderboardProvider: cannot load badges, no user');
      return;
    }

    _isLoadingBadges = true;
    notifyListeners();

    try {
      log('LeaderboardProvider: loading badges for $_currentUserId');
      _badges = await _badgeDataSource.fetchBadgesWithStatus(_currentUserId!);
      log('LeaderboardProvider: loaded ${_badges.length} badges, ${earnedBadges.length} earned');
    } catch (e) {
      log('LeaderboardProvider: error loading badges: $e');
      _badges = [];
    } finally {
      _isLoadingBadges = false;
      notifyListeners();
    }
  }

  /// Refresh all data.
  Future<void> refresh() async {
    log('LeaderboardProvider: refreshing all data');
    await Future.wait([
      loadLeaderboard(),
      loadBadges(),
    ]);
  }

  /// Get the total number of users in the current time period.
  int get totalParticipants => _entries.length;
}
