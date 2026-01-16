import 'package:flutter/material.dart';
import '../../domain/entities/event.dart';
import '../../domain/repositories/event_repository.dart';

// TODO: [SCALABILITY] Add pagination for past events
// Current: fetchPastEvents() loads all past events at once
// At scale: Years of events = unbounded memory growth
// Fix: Add limit/offset or cursor-based pagination for past events
// Upcoming events typically bounded naturally by time

/// Provider for managing events state and operations.
class EventsProvider with ChangeNotifier {
  final EventRepository _repository;

  EventsProvider(this._repository);

  // State
  List<EventEntity> _upcomingEvents = [];
  List<EventEntity> _pastEvents = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<EventEntity> get upcomingEvents => _upcomingEvents;
  List<EventEntity> get pastEvents => _pastEvents;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetches upcoming events.
  Future<void> fetchUpcomingEvents() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _upcomingEvents = await _repository.fetchEvents(filter: 'upcoming');
      _error = null;
    } catch (e) {
      _error = e.toString();
      _upcomingEvents = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches past events.
  Future<void> fetchPastEvents() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _pastEvents = await _repository.fetchEvents(filter: 'past');
      _error = null;
    } catch (e) {
      _error = e.toString();
      _pastEvents = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Creates a new event.
  Future<void> createEvent({
    required String title,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
    String? location,
    double? lat,
    double? lon,
    int? maxAttendees,
  }) async {
    try {
      await _repository.createEvent(
        title: title,
        description: description,
        startTime: startTime,
        endTime: endTime,
        location: location,
        lat: lat,
        lon: lon,
        maxAttendees: maxAttendees,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Joins an event (RSVP).
  Future<bool> joinEvent(String eventId) async {
    try {
      final success = await _repository.joinEvent(eventId);
      if (success) {
        // Update local state
        _updateEventAttendance(eventId, isAttending: true, increment: true);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Leaves an event (cancel RSVP).
  Future<bool> leaveEvent(String eventId) async {
    try {
      final success = await _repository.leaveEvent(eventId);
      if (success) {
        // Update local state
        _updateEventAttendance(eventId, isAttending: false, increment: false);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Updates the attendance status and count for a specific event in local state.
  void _updateEventAttendance(String eventId,
      {required bool isAttending, required bool increment}) {
    // Update in upcoming events
    final upcomingIndex =
        _upcomingEvents.indexWhere((event) => event.id == eventId);
    if (upcomingIndex != -1) {
      final event = _upcomingEvents[upcomingIndex];
      _upcomingEvents[upcomingIndex] = event.copyWith(
        isAttending: isAttending,
        attendeeCount: increment
            ? event.attendeeCount + 1
            : (event.attendeeCount > 0 ? event.attendeeCount - 1 : 0),
      );
    }

    // Update in past events
    final pastIndex = _pastEvents.indexWhere((event) => event.id == eventId);
    if (pastIndex != -1) {
      final event = _pastEvents[pastIndex];
      _pastEvents[pastIndex] = event.copyWith(
        isAttending: isAttending,
        attendeeCount: increment
            ? event.attendeeCount + 1
            : (event.attendeeCount > 0 ? event.attendeeCount - 1 : 0),
      );
    }
  }

  /// Fetches attendees for a specific event.
  Future<List<EventAttendee>> fetchEventAttendees(String eventId) async {
    try {
      return await _repository.fetchEventAttendees(eventId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  /// Clears error message.
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
