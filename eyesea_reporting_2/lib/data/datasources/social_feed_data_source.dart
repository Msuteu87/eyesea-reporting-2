import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/exceptions.dart';

/// Data source for social feed operations
class SocialFeedDataSource {
  final SupabaseClient _supabase;

  SocialFeedDataSource(this._supabase);

  /// Fetch social feed with optional filters
  /// Returns paginated feed items with thank counts and user thank status
  Future<List<Map<String, dynamic>>> fetchFeed({
    String? userId,
    String? country,
    String? city,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      log('Fetching social feed: country=$country, city=$city, limit=$limit, offset=$offset');

      final response = await _supabase.rpc('get_social_feed', params: {
        'p_user_id': userId,
        'p_country': country,
        'p_city': city,
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
}
