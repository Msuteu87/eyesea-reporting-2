import '../entities/event.dart';

abstract class EventRepository {
  Future<void> createEvent({
    required String title,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
    String? location,
    double? lat,
    double? lon,
  });

  Future<List<EventEntity>> fetchEvents();

  Future<List<EventEntity>> fetchMyEvents();
}
