/// Abstract repository for social feed operations.
abstract class SocialFeedRepository {
  /// Fetch social feed with optional filters (reports only - legacy).
  /// Returns paginated feed items with thank counts and user thank status.
  /// Supports proximity-based filtering with latitude, longitude, and radius.
  Future<List<Map<String, dynamic>>> fetchFeed({
    String? userId,
    String? country,
    String? city,
    double? latitude,
    double? longitude,
    int? radiusKm,
    int limit = 20,
    int offset = 0,
  });

  /// Fetch unified feed with both reports and events.
  /// Returns paginated items ordered by creation date.
  /// Supports proximity-based filtering with latitude, longitude, and radius.
  Future<List<Map<String, dynamic>>> fetchUnifiedFeed({
    String? userId,
    String? country,
    String? city,
    double? latitude,
    double? longitude,
    int? radiusKm,
    int limit = 20,
    int offset = 0,
  });

  /// Count reports within a radius (for auto-expand logic).
  Future<int> countReportsInRadius({
    required double latitude,
    required double longitude,
    required int radiusKm,
  });

  /// Toggle thank status for a report.
  /// Returns true if now thanked, false if unthanked.
  Future<bool> toggleThank(String reportId, String userId);

  /// Get thank count for a specific report.
  Future<int> getThankCount(String reportId);

  /// Check if user has thanked a report.
  Future<bool> hasUserThanked(String reportId, String userId);

  /// Toggle join status for an event.
  /// Returns true if now joined, false if left.
  Future<bool> toggleJoinEvent(String eventId, String userId);

  /// Get attendee count for an event.
  Future<int> getEventAttendeeCount(String eventId);
}
