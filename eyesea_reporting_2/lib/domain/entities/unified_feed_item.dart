import 'report.dart';

/// Sealed class representing items in the unified social feed.
/// Can be either a pollution report or a cleanup event.
sealed class UnifiedFeedItem {
  /// Unique identifier
  String get id;

  /// When the item was created
  DateTime get createdAt;

  /// Type discriminator: 'report' or 'event'
  String get itemType;

  /// User who created the item (reporter or organizer)
  String? get userId;

  /// Display name of the creator
  String? get displayName;

  /// Avatar URL of the creator
  String? get avatarUrl;

  /// Factory to parse JSON and return the appropriate subtype
  static UnifiedFeedItem fromJson(Map<String, dynamic> json) {
    final itemType = json['item_type'] as String? ?? 'report';

    if (itemType == 'event') {
      return EventFeedItem.fromJson(json);
    } else {
      return ReportFeedItem.fromJson(json);
    }
  }
}

/// A pollution report in the feed
class ReportFeedItem extends UnifiedFeedItem {
  @override
  final String id;

  @override
  final DateTime createdAt;

  @override
  String get itemType => 'report';

  @override
  final String? userId;

  @override
  final String? displayName;

  @override
  final String? avatarUrl;

  final String? city;
  final String? country;
  final PollutionType pollutionType;
  final int severity;
  final ReportStatus status;
  final String? notes;
  final double? totalWeightKg;
  final Map<PollutionType, int> pollutionCounts;
  final String? imageUrl;
  final List<String> sceneLabels;
  final int thanksCount;
  final bool userHasThanked;

  ReportFeedItem({
    required this.id,
    required this.createdAt,
    this.userId,
    this.displayName,
    this.avatarUrl,
    this.city,
    this.country,
    required this.pollutionType,
    required this.severity,
    required this.status,
    this.notes,
    this.totalWeightKg,
    this.pollutionCounts = const {},
    this.imageUrl,
    this.sceneLabels = const [],
    this.thanksCount = 0,
    this.userHasThanked = false,
  });

  factory ReportFeedItem.fromJson(Map<String, dynamic> json) {
    // Parse pollution type
    PollutionType pollutionType;
    final typeStr = json['pollution_type'] as String? ?? 'other';
    switch (typeStr) {
      case 'plastic':
        pollutionType = PollutionType.plastic;
        break;
      case 'oil':
        pollutionType = PollutionType.oil;
        break;
      case 'debris':
        pollutionType = PollutionType.debris;
        break;
      case 'sewage':
        pollutionType = PollutionType.sewage;
        break;
      case 'fishing_gear':
      case 'fishingGear':
        pollutionType = PollutionType.fishingGear;
        break;
      case 'container':
        pollutionType = PollutionType.container;
        break;
      default:
        pollutionType = PollutionType.other;
    }

    // Parse status
    ReportStatus status;
    final statusStr = json['status'] as String? ?? 'pending';
    switch (statusStr) {
      case 'verified':
        status = ReportStatus.verified;
        break;
      case 'resolved':
        status = ReportStatus.resolved;
        break;
      case 'rejected':
        status = ReportStatus.rejected;
        break;
      default:
        status = ReportStatus.pending;
    }

    // Parse pollution_counts from JSONB
    final pollutionCountsMap = <PollutionType, int>{};
    final countsData = json['pollution_counts'];
    if (countsData is Map) {
      for (final entry in countsData.entries) {
        final typeStr = entry.key.toString();
        final count = entry.value is int ? entry.value as int : 0;
        PollutionType type;
        switch (typeStr) {
          case 'plastic':
            type = PollutionType.plastic;
            break;
          case 'oil':
            type = PollutionType.oil;
            break;
          case 'debris':
            type = PollutionType.debris;
            break;
          case 'sewage':
            type = PollutionType.sewage;
            break;
          case 'fishingGear':
          case 'fishing_gear':
            type = PollutionType.fishingGear;
            break;
          case 'container':
            type = PollutionType.container;
            break;
          default:
            type = PollutionType.other;
        }
        pollutionCountsMap[type] = count;
      }
    }

    // Parse scene_labels
    List<String> sceneLabels = [];
    final labelsData = json['scene_labels'];
    if (labelsData is List) {
      sceneLabels = labelsData.map((e) => e.toString()).toList();
    }

    return ReportFeedItem(
      id: json['id'] as String,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      userId: json['user_id'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      pollutionType: pollutionType,
      severity: json['severity'] as int? ?? 3,
      status: status,
      notes: json['notes'] as String?,
      totalWeightKg: (json['total_weight_kg'] as num?)?.toDouble(),
      pollutionCounts: pollutionCountsMap,
      imageUrl: json['image_url'] as String?,
      sceneLabels: sceneLabels,
      thanksCount: (json['thanks_count'] as num?)?.toInt() ?? 0,
      userHasThanked: json['user_has_thanked'] as bool? ?? false,
    );
  }

  /// Create a copy with updated thank status (for optimistic updates)
  ReportFeedItem copyWith({
    int? thanksCount,
    bool? userHasThanked,
  }) {
    return ReportFeedItem(
      id: id,
      createdAt: createdAt,
      userId: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      city: city,
      country: country,
      pollutionType: pollutionType,
      severity: severity,
      status: status,
      notes: notes,
      totalWeightKg: totalWeightKg,
      pollutionCounts: pollutionCounts,
      imageUrl: imageUrl,
      sceneLabels: sceneLabels,
      thanksCount: thanksCount ?? this.thanksCount,
      userHasThanked: userHasThanked ?? this.userHasThanked,
    );
  }

  /// Get total item count from pollution counts
  int get totalItems {
    return pollutionCounts.values.fold(0, (sum, count) => sum + count);
  }

  /// Get formatted location string
  String get locationString {
    if (city != null && country != null) {
      return '$city, $country';
    } else if (country != null) {
      return country!;
    } else if (city != null) {
      return city!;
    }
    return 'Unknown location';
  }

  /// Get formatted weight string
  String get weightString {
    if (totalWeightKg == null) return '';
    if (totalWeightKg! >= 1) {
      return '${totalWeightKg!.toStringAsFixed(1)} kg';
    } else {
      return '${(totalWeightKg! * 1000).toStringAsFixed(0)} g';
    }
  }
}

/// A cleanup event in the feed
class EventFeedItem extends UnifiedFeedItem {
  @override
  final String id;

  @override
  final DateTime createdAt;

  @override
  String get itemType => 'event';

  @override
  final String? userId;

  @override
  final String? displayName;

  @override
  final String? avatarUrl;

  final String title;
  final String? description;
  final String? address;
  final DateTime startTime;
  final DateTime? endTime;
  final String status;
  final int? maxAttendees;
  final int attendeeCount;
  final bool userHasJoined;
  final String? coverImageUrl;

  EventFeedItem({
    required this.id,
    required this.createdAt,
    this.userId,
    this.displayName,
    this.avatarUrl,
    required this.title,
    this.description,
    this.address,
    required this.startTime,
    this.endTime,
    required this.status,
    this.maxAttendees,
    this.attendeeCount = 0,
    this.userHasJoined = false,
    this.coverImageUrl,
  });

  factory EventFeedItem.fromJson(Map<String, dynamic> json) {
    return EventFeedItem(
      id: json['id'] as String,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      userId: json['user_id'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      title: json['event_title'] as String? ?? 'Cleanup Event',
      description: json['event_description'] as String?,
      address: json['event_address'] as String?,
      startTime: DateTime.tryParse(json['event_start_time'] as String? ?? '') ?? DateTime.now(),
      endTime: json['event_end_time'] != null 
          ? DateTime.tryParse(json['event_end_time'] as String) 
          : null,
      status: json['event_status'] as String? ?? 'planned',
      maxAttendees: json['event_max_attendees'] as int?,
      attendeeCount: (json['event_attendee_count'] as num?)?.toInt() ?? 0,
      userHasJoined: json['user_has_joined'] as bool? ?? false,
      coverImageUrl: json['event_cover_image_url'] as String?,
    );
  }

  /// Create a copy with updated join status (for optimistic updates)
  EventFeedItem copyWith({
    int? attendeeCount,
    bool? userHasJoined,
  }) {
    return EventFeedItem(
      id: id,
      createdAt: createdAt,
      userId: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      title: title,
      description: description,
      address: address,
      startTime: startTime,
      endTime: endTime,
      status: status,
      maxAttendees: maxAttendees,
      attendeeCount: attendeeCount ?? this.attendeeCount,
      userHasJoined: userHasJoined ?? this.userHasJoined,
      coverImageUrl: coverImageUrl,
    );
  }

  /// Check if event is full
  bool get isFull => maxAttendees != null && attendeeCount >= maxAttendees!;

  /// Get spots remaining text
  String get spotsRemainingText {
    if (maxAttendees == null) return 'Open event';
    final remaining = maxAttendees! - attendeeCount;
    if (remaining <= 0) return 'Event full';
    return '$remaining spots left';
  }

  /// Format the event date/time
  String get formattedDateTime {
    final now = DateTime.now();
    final isToday = startTime.year == now.year && 
                    startTime.month == now.month && 
                    startTime.day == now.day;
    final isTomorrow = startTime.year == now.year && 
                       startTime.month == now.month && 
                       startTime.day == now.day + 1;

    final timeStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';

    if (isToday) {
      return 'Today at $timeStr';
    } else if (isTomorrow) {
      return 'Tomorrow at $timeStr';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[startTime.month - 1]} ${startTime.day} at $timeStr';
    }
  }
}
