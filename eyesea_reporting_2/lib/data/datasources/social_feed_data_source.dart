import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/exceptions.dart';

/// Data source for social feed operations
class SocialFeedDataSource {
  final SupabaseClient _supabase;

  SocialFeedDataSource(this._supabase);

  /// Fetch social feed with optional filters (reports only - legacy)
  /// Returns paginated feed items with thank counts and user thank status
  /// Supports proximity-based filtering with latitude, longitude, and radius
  Future<List<Map<String, dynamic>>> fetchFeed({
    String? userId,
    String? country,
    String? city,
    double? latitude,
    double? longitude,
    int? radiusKm,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      log('Fetching social feed: lat=$latitude, lng=$longitude, radius=${radiusKm}km, country=$country, city=$city, limit=$limit, offset=$offset');

      final response = await _supabase.rpc('get_social_feed', params: {
        'p_user_id': userId,
        'p_country': country,
        'p_city': city,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_radius_km': radiusKm,
        'p_limit': limit,
        'p_offset': offset,
      });

      final items = List<Map<String, dynamic>>.from(response ?? []);
      log('Fetched ${items.length} feed items');
      return items;
    } catch (e) {
      log('Error fetching social feed: $e');
      throw ServerException(message: e.toString());
    }
  }

  /// Fetch unified feed including both reports and events
  /// Returns paginated items ordered by creation date
  /// Supports proximity-based filtering with latitude, longitude, and radius
  Future<List<Map<String, dynamic>>> fetchUnifiedFeed({
    String? userId,
    String? country,
    String? city,
    double? latitude,
    double? longitude,
    int? radiusKm,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      log('Fetching unified feed: lat=$latitude, lng=$longitude, radius=${radiusKm}km, country=$country, city=$city, limit=$limit, offset=$offset');

      final response = await _supabase.rpc('get_unified_feed', params: {
        'p_user_id': userId,
        'p_country': country,
        'p_city': city,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_radius_km': radiusKm,
        'p_limit': limit,
        'p_offset': offset,
      });

      final items = List<Map<String, dynamic>>.from(response ?? []);
      log('Fetched ${items.length} unified feed items (reports + events)');
      return items;
    } catch (e) {
      log('Error fetching unified feed: $e');
      throw ServerException(message: e.toString());
    }
  }

  /// Count reports within a radius (for auto-expand logic)
  Future<int> countReportsInRadius({
    required double latitude,
    required double longitude,
    required int radiusKm,
  }) async {
    try {
      final response = await _supabase.rpc('count_reports_in_radius', params: {
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_radius_km': radiusKm,
      });
      return response as int? ?? 0;
    } catch (e) {
      log('Error counting reports in radius: $e');
      return 0;
    }
  }

  /// Toggle thank status for a report
  /// Returns true if now thanked, false if unthanked
  Future<bool> toggleThank(String reportId, String userId) async {
    try {
      log('Toggling thank for report=$reportId, user=$userId');

      // Check if already thanked
      final existing = await _supabase
          .from('report_thanks')
          .select('id')
          .eq('report_id', reportId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        // Remove thank
        await _supabase
            .from('report_thanks')
            .delete()
            .eq('report_id', reportId)
            .eq('user_id', userId);
        log('Removed thank for report=$reportId');
        return false; // No longer thanked
      } else {
        // Add thank
        await _supabase.from('report_thanks').insert({
          'report_id': reportId,
          'user_id': userId,
        });
        log('Added thank for report=$reportId');
        return true; // Now thanked
      }
    } catch (e) {
      log('Error toggling thank: $e');
      throw ServerException(message: e.toString());
    }
  }

  /// Get thank count for a specific report
  Future<int> getThankCount(String reportId) async {
    try {
      final response = await _supabase
          .from('report_thanks')
          .select()
          .eq('report_id', reportId)
          .count(CountOption.exact);
      return response.count;
    } catch (e) {
      log('Error getting thank count: $e');
      throw ServerException(message: e.toString());
    }
  }

  /// Check if user has thanked a report
  Future<bool> hasUserThanked(String reportId, String userId) async {
    try {
      final response = await _supabase
          .from('report_thanks')
          .select('id')
          .eq('report_id', reportId)
          .eq('user_id', userId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      log('Error checking user thank status: $e');
      return false;
    }
  }

  /// Toggle join status for an event
  /// Returns true if now joined, false if left
  Future<bool> toggleJoinEvent(String eventId, String userId) async {
    try {
      log('Toggling join for event=$eventId, user=$userId');

      // Check if already joined
      final existing = await _supabase
          .from('event_participants')
          .select('event_id')
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        // Leave event (update status to cancelled)
        await _supabase
            .from('event_participants')
            .update({'status': 'cancelled'})
            .eq('event_id', eventId)
            .eq('user_id', userId);
        log('Left event=$eventId');
        return false; // No longer joined
      } else {
        // Join event (upsert to handle re-joining)
        await _supabase.from('event_participants').upsert({
          'event_id': eventId,
          'user_id': userId,
          'status': 'joined',
          'joined_at': DateTime.now().toIso8601String(),
        }, onConflict: 'event_id,user_id');
        log('Joined event=$eventId');
        return true; // Now joined
      }
    } catch (e) {
      log('Error toggling event join: $e');
      throw ServerException(message: e.toString());
    }
  }

  /// Get attendee count for an event
  Future<int> getEventAttendeeCount(String eventId) async {
    try {
      final response = await _supabase
          .from('event_participants')
          .select()
          .eq('event_id', eventId)
          .inFilter('status', ['joined', 'checked_in'])
          .count(CountOption.exact);
      return response.count;
    } catch (e) {
      log('Error getting event attendee count: $e');
      return 0;
    }
  }
}
