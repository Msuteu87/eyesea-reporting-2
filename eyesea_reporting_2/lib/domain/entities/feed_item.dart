import 'report.dart';

/// Represents a single item in the social feed
class FeedItem {
  final String id;
  final String? userId;
  final String? displayName;
  final String? avatarUrl;
  final String? city;
  final String? country;
  final PollutionType pollutionType;
  final int severity;
  final ReportStatus status;
  final String? notes;
  final DateTime reportedAt;
  final double? totalWeightKg;
  final Map<PollutionType, int> pollutionCounts;
  final String? imageUrl;
  final List<String> sceneLabels;
  final int thanksCount;
  final bool userHasThanked;

  const FeedItem({
    required this.id,
    this.userId,
    this.displayName,
    this.avatarUrl,
    this.city,
    this.country,
    required this.pollutionType,
    required this.severity,
    required this.status,
    this.notes,
    required this.reportedAt,
    this.totalWeightKg,
    this.pollutionCounts = const {},
    this.imageUrl,
    this.sceneLabels = const [],
    this.thanksCount = 0,
    this.userHasThanked = false,
  });

  /// Factory constructor to create FeedItem from Supabase JSON response
  factory FeedItem.fromJson(Map<String, dynamic> json) {
    // Parse pollution type from snake_case DB value
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

    return FeedItem(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      pollutionType: pollutionType,
      severity: json['severity'] as int? ?? 3,
      status: status,
      notes: json['notes'] as String?,
      reportedAt: DateTime.tryParse(json['reported_at'] as String? ?? '') ?? DateTime.now(),
      totalWeightKg: (json['total_weight_kg'] as num?)?.toDouble(),
      pollutionCounts: pollutionCountsMap,
      imageUrl: json['image_url'] as String?,
      sceneLabels: sceneLabels,
      thanksCount: (json['thanks_count'] as num?)?.toInt() ?? 0,
      userHasThanked: json['user_has_thanked'] as bool? ?? false,
    );
  }

  /// Create a copy with updated thank status (for optimistic updates)
  FeedItem copyWith({
    int? thanksCount,
    bool? userHasThanked,
  }) {
    return FeedItem(
      id: id,
      userId: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      city: city,
      country: country,
      pollutionType: pollutionType,
      severity: severity,
      status: status,
      notes: notes,
      reportedAt: reportedAt,
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
