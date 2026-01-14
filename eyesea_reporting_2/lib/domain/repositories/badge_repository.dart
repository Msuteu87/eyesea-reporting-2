import '../entities/badge.dart';

/// Abstract repository for badge and gamification operations.
abstract class BadgeRepository {
  /// Fetch badges earned by a specific user.
  Future<List<BadgeEntity>> fetchUserBadges(String userId);

  /// Fetch all available badges (for showing locked/earned status).
  Future<List<BadgeEntity>> fetchAllBadges();

  /// Fetch user's leaderboard rank and stats.
  Future<UserStats> fetchUserRank(String userId, {int streakDays = 0});

  /// Fetch user's total XP.
  Future<int> fetchUserTotalXp(String userId);

  /// Fetch leaderboard (top users).
  Future<List<Map<String, dynamic>>> fetchLeaderboard({int limit = 10});

  /// Get combined badges list with earned status.
  /// Returns all badges with isEarned=true for earned ones.
  Future<List<BadgeEntity>> fetchBadgesWithStatus(String userId);
}
