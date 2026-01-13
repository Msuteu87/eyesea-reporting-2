/// Represents a cleanup event that users can attend.
class EventEntity {
  final String id;
  final String organizerId;
  final String organizerName;
  final String? organizerAvatar;
  final String title;
  final String description;
  final String? address;
  final double? lat;
  final double? lng;
  final DateTime startTime;
  final DateTime endTime;
  final int? maxAttendees;
  final String status; // 'planned', 'ongoing', 'completed', 'cancelled'
  final DateTime createdAt;
  final int attendeeCount;
  final bool isAttending;

  const EventEntity({
    required this.id,
    required this.organizerId,
    required this.organizerName,
    this.organizerAvatar,
    required this.title,
    required this.description,
    this.address,
    this.lat,
    this.lng,
    required this.startTime,
    required this.endTime,
    this.maxAttendees,
    this.status = 'planned',
    required this.createdAt,
    this.attendeeCount = 0,
    this.isAttending = false,
  });

  factory EventEntity.fromJson(Map<String, dynamic> json) {
    return EventEntity(
      id: json['id'] as String,
      organizerId: json['organizer_id'] as String,
      organizerName: json['organizer_name'] as String? ?? 'Unknown',
      organizerAvatar: json['organizer_avatar'] as String?,
      title: json['title'] as String,
      description: json['description'] as String,
      address: json['address'] as String?,
      lat: (json['location_lat'] as num?)?.toDouble(),
      lng: (json['location_lng'] as num?)?.toDouble(),
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      maxAttendees: json['max_attendees'] as int?,
      status: json['status'] as String? ?? 'planned',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      attendeeCount: (json['attendee_count'] as num?)?.toInt() ?? 0,
      isAttending: json['is_attending'] as bool? ?? false,
    );
  }

  /// Returns true if the event is in the past.
  bool get isPast => endTime.isBefore(DateTime.now());

  /// Returns true if the event is upcoming (starts in the future).
  bool get isUpcoming => startTime.isAfter(DateTime.now());

  /// Returns true if the event is currently ongoing.
  bool get isOngoing =>
      startTime.isBefore(DateTime.now()) && endTime.isAfter(DateTime.now());

  /// Returns true if the event is full (max capacity reached).
  bool get isFull =>
      maxAttendees != null && attendeeCount >= maxAttendees!;

  /// Returns formatted date string (e.g., "Jan 15, 2026").
  String get formattedDate {
    final month = _monthName(startTime.month);
    return '$month ${startTime.day}, ${startTime.year}';
  }

  /// Returns formatted time range (e.g., "10:00 AM - 2:00 PM").
  String get formattedTimeRange {
    return '${_formatTime(startTime)} - ${_formatTime(endTime)}';
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0
        ? 12
        : dt.hour > 12
            ? dt.hour - 12
            : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  EventEntity copyWith({
    String? id,
    String? organizerId,
    String? organizerName,
    String? organizerAvatar,
    String? title,
    String? description,
    String? address,
    double? lat,
    double? lng,
    DateTime? startTime,
    DateTime? endTime,
    int? maxAttendees,
    String? status,
    DateTime? createdAt,
    int? attendeeCount,
    bool? isAttending,
  }) {
    return EventEntity(
      id: id ?? this.id,
      organizerId: organizerId ?? this.organizerId,
      organizerName: organizerName ?? this.organizerName,
      organizerAvatar: organizerAvatar ?? this.organizerAvatar,
      title: title ?? this.title,
      description: description ?? this.description,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      maxAttendees: maxAttendees ?? this.maxAttendees,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      attendeeCount: attendeeCount ?? this.attendeeCount,
      isAttending: isAttending ?? this.isAttending,
    );
  }
}

/// Represents an event attendee with user info.
class EventAttendee {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final DateTime joinedAt;

  const EventAttendee({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.joinedAt,
  });

  factory EventAttendee.fromJson(Map<String, dynamic> json) {
    return EventAttendee(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String? ?? 'Anonymous',
      avatarUrl: json['avatar_url'] as String?,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }
}
