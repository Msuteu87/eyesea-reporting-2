import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/event.dart';

/// Data source for event-related API calls to Supabase.
class EventDataSource {
  final SupabaseClient _supabaseClient;

  EventDataSource(this._supabaseClient);

  /// Creates a new event in the database.
  Future<void> createEvent(Map<String, dynamic> eventData) async {
    try {
      await _supabaseClient.from('events').insert(eventData);
    } catch (e) {
      AppLogger.error('Error creating event', e);
      throw Exception('Failed to create event');
    }
  }

  /// Fetches events using the RPC function with filtering.
  Future<List<EventEntity>> fetchEvents({String filter = 'upcoming'}) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;

      final response = await _supabaseClient.rpc(
        'get_events_with_details',
        params: {
          'p_user_id': userId,
          'p_filter': filter,
          'p_limit': 50,
        },
      );

      return (response as List)
          .map((json) => EventEntity.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Error fetching events', e);
      throw Exception('Failed to fetch events');
    }
  }

  /// Fetches attendees for a specific event.
  Future<List<EventAttendee>> fetchEventAttendees(String eventId) async {
    try {
      final response = await _supabaseClient.rpc(
        'get_event_attendees',
        params: {'p_event_id': eventId},
      );

      return (response as List)
          .map((json) => EventAttendee.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Error fetching event attendees', e);
      throw Exception('Failed to fetch attendees');
    }
  }

  /// Joins an event (RSVP).
  Future<bool> joinEvent(String eventId) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabaseClient.rpc(
        'join_event',
        params: {
          'p_event_id': eventId,
          'p_user_id': userId,
        },
      );

      return response['success'] == true;
    } catch (e) {
      AppLogger.error('Error joining event', e);
      throw Exception('Failed to join event');
    }
  }

  /// Leaves an event (cancels RSVP).
  Future<bool> leaveEvent(String eventId) async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabaseClient.rpc(
        'leave_event',
        params: {
          'p_event_id': eventId,
          'p_user_id': userId,
        },
      );

      return response['success'] == true;
    } catch (e) {
      AppLogger.error('Error leaving event', e);
      throw Exception('Failed to leave event');
    }
  }
}
