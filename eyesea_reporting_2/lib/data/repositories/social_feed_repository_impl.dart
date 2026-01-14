import '../../domain/repositories/social_feed_repository.dart';
import '../datasources/social_feed_data_source.dart';

/// Implementation of [SocialFeedRepository] using Supabase.
class SocialFeedRepositoryImpl implements SocialFeedRepository {
  final SocialFeedDataSource _dataSource;

  SocialFeedRepositoryImpl(this._dataSource);

  @override
  Future<List<Map<String, dynamic>>> fetchFeed({
    String? userId,
    String? country,
    String? city,
    double? latitude,
    double? longitude,
    int? radiusKm,
    int limit = 20,
    int offset = 0,
  }) {
    return _dataSource.fetchFeed(
      userId: userId,
      country: country,
      city: city,
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<int> countReportsInRadius({
    required double latitude,
    required double longitude,
    required int radiusKm,
  }) {
    return _dataSource.countReportsInRadius(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
    );
  }

  @override
  Future<bool> toggleThank(String reportId, String userId) {
    return _dataSource.toggleThank(reportId, userId);
  }

  @override
  Future<int> getThankCount(String reportId) {
    return _dataSource.getThankCount(reportId);
  }

  @override
  Future<bool> hasUserThanked(String reportId, String userId) {
    return _dataSource.hasUserThanked(reportId, userId);
  }
}
