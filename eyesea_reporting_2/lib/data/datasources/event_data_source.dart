import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/event.dart';

class EventDataSource {
  final SupabaseClient _supabaseClient;

  EventDataSource(this._supabaseClient);

  Future<void> createEvent(Map<String, dynamic> eventData) async {
    try {
      await _supabaseClient.from('events').insert(eventData);
    } catch (e) {
      AppLogger.error('Error creating event', e);
      throw Exception('Failed to create event');
    }
  }

  Future<List<EventEntity>> fetchEvents({bool onlyMyEvents = false}) async {
    try {
      var query = _supabaseClient.from('events').select();

      if (onlyMyEvents) {
        final userId = _supabaseClient.auth.currentUser?.id;
        if (userId != null) {
          query = query.eq('organizer_id', userId);
        }
      }

      // Order by start time desc
      final data = await query.order('start_time', ascending: false);

      return (data as List).map((json) => _mapEvent(json)).toList();
    } catch (e) {
      AppLogger.error('Error fetching events', e);
      throw Exception('Failed to fetch events');
    }
  }

  EventEntity _mapEvent(Map<String, dynamic> json) {
    return EventEntity(
      id: json['id'],
      organizerId: json['organizer_id'],
      title: json['title'],
      description: json['description'] ?? '',
      location:
          json['location_text'], // Assuming location_text usage or fallback
      // Lat/Lon might need parsing if stored as geography, or separate columns
      // Schema proposal said "location geography(POINT)".
      // Handling PostGIS point in Supabase allows extracting lat/long, or we stored them separately?
      // Proposal: "location (geography POINT), address (text)".
      // Let's assume we read 'address' for location text.
      // And we might need a way to parse POINT if we want lat/lon.
      // For now let's use 'address' field.
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
      status: json['status'],
    );
  }
}
