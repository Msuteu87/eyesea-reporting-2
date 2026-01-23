import '../entities/event.dart';

/// Repository interface for event-related operations.
abstract class EventRepository {
  /// Creates a new cleanup event.
  /// [coverImagePath] is the local file path of the cover image to upload.
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
  });

  /// Fetches events with optional filtering.
  /// [filter] can be: 'upcoming', 'past', 'my_organized', 'my_attending'
  Future<List<EventEntity>> fetchEvents({String filter = 'upcoming'});

  /// Fetches attendees for a specific event.
  Future<List<EventAttendee>> fetchEventAttendees(String eventId);

  /// Joins an event (RSVP).
  Future<bool> joinEvent(String eventId);

  /// Leaves an event (cancel RSVP).
  Future<bool> leaveEvent(String eventId);
}
