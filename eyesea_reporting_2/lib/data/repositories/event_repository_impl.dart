import '../../domain/entities/event.dart';
import '../../domain/repositories/event_repository.dart';
import '../datasources/event_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  }) async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final eventData = {
      'organizer_id': user.id,
      'title': title,
      'description': description,
      'address': location,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'status': 'planned',
      'location': 'POINT(${lon ?? 0} ${lat ?? 0})', // PostGIS format
    };

    await _dataSource.createEvent(eventData);
  }

  @override
  Future<List<EventEntity>> fetchEvents() async {
    return _dataSource.fetchEvents();
  }

  @override
  Future<List<EventEntity>> fetchMyEvents() async {
    return _dataSource.fetchEvents(onlyMyEvents: true);
  }
}
