import '../../domain/entities/badge.dart';
import '../../domain/repositories/badge_repository.dart';
import '../datasources/badge_data_source.dart';

/// Implementation of [BadgeRepository] using Supabase.
class BadgeRepositoryImpl implements BadgeRepository {
  final BadgeDataSource _dataSource;

  BadgeRepositoryImpl(this._dataSource);

  @override
  Future<List<BadgeEntity>> fetchUserBadges(String userId) {
    return _dataSource.fetchUserBadges(userId);
  }

  @override
  Future<List<BadgeEntity>> fetchAllBadges() {
    return _dataSource.fetchAllBadges();
  }

  @override
  Future<UserStats> fetchUserRank(String userId, {int streakDays = 0}) {
    return _dataSource.fetchUserRank(userId, streakDays: streakDays);
  }

  @override
  Future<int> fetchUserTotalXp(String userId) {
    return _dataSource.fetchUserTotalXp(userId);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchLeaderboard({int limit = 10}) {
    return _dataSource.fetchLeaderboard(limit: limit);
  }

  @override
  Future<List<BadgeEntity>> fetchBadgesWithStatus(String userId) {
    return _dataSource.fetchBadgesWithStatus(userId);
  }
}
