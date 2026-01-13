import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/exceptions.dart';
import '../../domain/entities/badge.dart';

/// Data source for badge and gamification operations.
class BadgeDataSource {
  final SupabaseClient _supabase;

  BadgeDataSource(this._supabase);

  /// Fetch badges earned by a specific user.
  Future<List<BadgeEntity>> fetchUserBadges(String userId) async {
    try {
      final response = await _supabase.rpc('get_user_badges', params: {
        'p_user_id': userId,
      });

      final badges = (response as List)
          .map((json) =>
              BadgeEntity.fromJson(json as Map<String, dynamic>, earned: true))
          .toList();

      return badges;
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  /// Fetch all available badges (for showing locked/earned status).
  Future<List<BadgeEntity>> fetchAllBadges() async {
    try {
      final response = await _supabase.rpc('get_all_badges');

      final badges = (response as List)
          .map((json) =>
              BadgeEntity.fromJson(json as Map<String, dynamic>, earned: false))
          .toList();

      return badges;
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  /// Fetch user's leaderboard rank and stats.
  Future<UserStats> fetchUserRank(String userId, {int streakDays = 0}) async {
    try {
      final response = await _supabase.rpc('get_user_rank', params: {
        'p_user_id': userId,
      });

      if (response == null || (response as List).isEmpty) {
        return UserStats.empty;
      }

      return UserStats.fromJson(
        response[0] as Map<String, dynamic>,
        streakDays: streakDays,
      );
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  /// Fetch user's total XP.
  Future<int> fetchUserTotalXp(String userId) async {
    try {
      final response = await _supabase.rpc('get_user_total_xp', params: {
        'p_user_id': userId,
      });

      return (response as num?)?.toInt() ?? 0;
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  /// Fetch leaderboard (top users).
  Future<List<Map<String, dynamic>>> fetchLeaderboard({int limit = 10}) async {
    try {
      final response = await _supabase.rpc('get_leaderboard', params: {
        'p_limit': limit,
      });

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  /// Get combined badges list with earned status.
  /// Returns all badges with isEarned=true for earned ones.
  Future<List<BadgeEntity>> fetchBadgesWithStatus(String userId) async {
    try {
      final allBadges = await fetchAllBadges();
      final userBadges = await fetchUserBadges(userId);

      final earnedSlugs = userBadges.map((b) => b.slug).toSet();

      return allBadges.map((badge) {
        if (earnedSlugs.contains(badge.slug)) {
          final earned = userBadges.firstWhere((b) => b.slug == badge.slug);
          return badge.copyWith(
            isEarned: true,
            earnedAt: earned.earnedAt,
          );
        }
        return badge;
      }).toList();
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
