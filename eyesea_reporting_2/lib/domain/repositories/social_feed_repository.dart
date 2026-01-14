/// Abstract repository for social feed operations.
abstract class SocialFeedRepository {
  /// Fetch social feed with optional filters.
  /// Returns paginated feed items with thank counts and user thank status.
  Future<List<Map<String, dynamic>>> fetchFeed({
    String? userId,
    String? country,
    String? city,
    int limit = 20,
    int offset = 0,
  });

  /// Toggle thank status for a report.
  /// Returns true if now thanked, false if unthanked.
  Future<bool> toggleThank(String reportId, String userId);

  /// Get thank count for a specific report.
  Future<int> getThankCount(String reportId);

  /// Check if user has thanked a report.
  Future<bool> hasUserThanked(String reportId, String userId);
}
