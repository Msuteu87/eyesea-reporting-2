import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/exceptions.dart';
import '../../domain/entities/category_rank.dart';
import '../../domain/entities/leaderboard_entry.dart';

/// Leaderboard category types.
enum LeaderboardCategory {
  users,
  organizations,
  vessels,
}

/// Time filter options for leaderboard data.
enum TimeFilter {
  last30Days(30, 'Last 30 Days'),
  last90Days(90, 'Last 90 Days'),
  lastYear(365, 'Last Year');

  final int days;
  final String label;
  const TimeFilter(this.days, this.label);
}

/// Data source for leaderboard operations.
class LeaderboardDataSource {
  final SupabaseClient _supabase;

  LeaderboardDataSource(this._supabase);

  /// Fetch user leaderboard with time filtering.
  Future<List<LeaderboardEntry>> fetchUserLeaderboard({
    TimeFilter timeFilter = TimeFilter.last30Days,
    int limit = 50,
  }) async {
    try {
      final response = await _supabase.rpc('get_user_leaderboard', params: {
        'p_days': timeFilter.days,
        'p_limit': limit,
      });

      return (response as List)
          .map((json) =>
              LeaderboardEntry.fromUserJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      log('Error fetching user leaderboard: $e');
      throw ServerException(message: e.toString());
    }
  }

  /// Fetch organization leaderboard with time filtering.
  Future<List<LeaderboardEntry>> fetchOrganizationLeaderboard({
    TimeFilter timeFilter = TimeFilter.last30Days,
    int limit = 50,
  }) async {
    try {
      final response =
          await _supabase.rpc('get_organization_leaderboard', params: {
        'p_days': timeFilter.days,
        'p_limit': limit,
      });

      return (response as List)
          .map((json) =>
              LeaderboardEntry.fromOrgJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      log('Error fetching organization leaderboard: $e');
      throw ServerException(message: e.toString());
    }
  }

  /// Fetch vessel leaderboard with time filtering.
  Future<List<LeaderboardEntry>> fetchVesselLeaderboard({
    TimeFilter timeFilter = TimeFilter.last30Days,
    int limit = 50,
  }) async {
    try {
      final response = await _supabase.rpc('get_vessel_leaderboard', params: {
        'p_days': timeFilter.days,
        'p_limit': limit,
      });

      return (response as List)
          .map((json) =>
              LeaderboardEntry.fromVesselJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      log('Error fetching vessel leaderboard: $e');
      throw ServerException(message: e.toString());
    }
  }

  /// Fetch leaderboard entries for any category.
  Future<List<LeaderboardEntry>> fetchLeaderboard({
    required LeaderboardCategory category,
    TimeFilter timeFilter = TimeFilter.last30Days,
    int limit = 50,
  }) async {
    return switch (category) {
      LeaderboardCategory.users =>
        fetchUserLeaderboard(timeFilter: timeFilter, limit: limit),
      LeaderboardCategory.organizations =>
        fetchOrganizationLeaderboard(timeFilter: timeFilter, limit: limit),
      LeaderboardCategory.vessels =>
        fetchVesselLeaderboard(timeFilter: timeFilter, limit: limit),
    };
  }

  /// Fetch current user's rank in a specific category.
  Future<CategoryRank?> fetchUserCategoryRank({
    required String userId,
    required LeaderboardCategory category,
    TimeFilter timeFilter = TimeFilter.last30Days,
  }) async {
    try {
      final categoryStr = switch (category) {
        LeaderboardCategory.users => 'user',
        LeaderboardCategory.organizations => 'organization',
        LeaderboardCategory.vessels => 'vessel',
      };

      final response = await _supabase.rpc('get_user_category_rank', params: {
        'p_user_id': userId,
        'p_category': categoryStr,
        'p_days': timeFilter.days,
      });

      if (response == null || (response as List).isEmpty) {
        return null;
      }

      return CategoryRank.fromJson(response[0] as Map<String, dynamic>);
    } catch (e) {
      log('Error fetching user category rank: $e');
      throw ServerException(message: e.toString());
    }
  }
}
