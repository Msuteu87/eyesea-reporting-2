import 'dart:io';
import '../../domain/entities/event.dart';
import '../../domain/repositories/event_repository.dart';
import '../datasources/event_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Implementation of EventRepository using EventDataSource.
class EventRepositoryImpl implements EventRepository {
  final EventDataSource _dataSource;
  final SupabaseClient _supabaseClient;

  EventRepositoryImpl(this._dataSource, this._supabaseClient);

  @override
  Future<void> createEvent({
    required String title,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
    String? location,
    double? lat,
    double? lon,
    int? maxAttendees,
    String? coverImagePath,
  }) async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Upload cover image if provided
    String? coverImageUrl;
    if (coverImagePath != null && coverImagePath.isNotEmpty) {
      final imageFile = File(coverImagePath);
      if (imageFile.existsSync()) {
        coverImageUrl = await _dataSource.uploadEventImage(imageFile);
      }
    }

    final eventData = {
      'organizer_id': user.id,
      'title': title,
      'description': description,
      'address': location,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'status': 'planned',
      'location': 'POINT(${lon ?? 0} ${lat ?? 0})', // PostGIS format
      if (maxAttendees != null) 'max_attendees': maxAttendees,
      if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
    };

    await _dataSource.createEvent(eventData);
  }

  @override
  Future<List<EventEntity>> fetchEvents({String filter = 'upcoming'}) async {
    return _dataSource.fetchEvents(filter: filter);
  }

  @override
  Future<List<EventAttendee>> fetchEventAttendees(String eventId) async {
    return _dataSource.fetchEventAttendees(eventId);
  }

  @override
  Future<bool> joinEvent(String eventId) async {
    return _dataSource.joinEvent(eventId);
  }

  @override
  Future<bool> leaveEvent(String eventId) async {
    return _dataSource.leaveEvent(eventId);
  }
}
