import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

enum PollutionType {
  plastic,
  oil,
  debris,
  sewage,
  fishingGear, // maps to fishing_gear in DB
  container,
  other;

  String get displayLabel {
    switch (this) {
      case PollutionType.plastic:
        return 'Plastic';
      case PollutionType.oil:
        return 'Oil';
      case PollutionType.debris:
        return 'Debris';
      case PollutionType.sewage:
        return 'Sewage';
      case PollutionType.fishingGear:
        return 'Fishing Gear';
      case PollutionType.container:
        return 'Container';
      case PollutionType.other:
        return 'Other';
    }
  }
}

enum ReportStatus {
  pending,
  verified,
  resolved,
  rejected,
}

class ReportEntity {
  final String id;
  final String userId;
  final String? orgId;
  final Point location;
  final String? address;
  final PollutionType pollutionType;
  final int severity; // 1-5
  final ReportStatus status;
  final String? notes;
  final bool isAnonymous;
  final DateTime reportedAt;
  final List<String> imageUrls;
  final String? city;
  final String? country;
  final double? totalWeightKg;
  final Map<PollutionType, int> pollutionCounts;
  final int? xpEarned;

  ReportEntity({
    required this.id,
    required this.userId,
    this.orgId,
    required this.location,
    this.address,
    required this.pollutionType,
    required this.severity,
    this.status = ReportStatus.pending,
    this.notes,
    this.isAnonymous = false,
    required this.reportedAt,
    this.imageUrls = const [],
    this.city,
    this.country,
    this.totalWeightKg,
    this.pollutionCounts = const {},
    this.xpEarned,
  });

  /// Factory constructor to create ReportEntity from Supabase JSON response
  factory ReportEntity.fromJson(Map<String, dynamic> json) {
    // Parse location from PostGIS format
    // Supabase returns geography as hex-encoded WKB or as text depending on config
    Point location;
    final locationData = json['location'];

    debugPrint(
        '📍 Parsing location: $locationData (type: ${locationData.runtimeType})');

    if (locationData is String) {
      if (locationData.startsWith('POINT')) {
        // Parse "POINT(lng lat)" format
        final coords = locationData
            .replaceAll('POINT(', '')
            .replaceAll(')', '')
            .split(' ');
        location = Point(
          coordinates: Position(
            double.parse(coords[0]), // longitude
            double.parse(coords[1]), // latitude
          ),
        );
      } else if (locationData.startsWith('0101')) {
        // Hex-encoded WKB - need to extract coordinates differently
        // This is PostGIS binary format, we can't easily parse it
        // Fallback to 0,0 - we need to fix the query to return as text
        debugPrint('⚠️ Location is WKB hex format - need ST_AsText in query');
        location = Point(coordinates: Position(0, 0));
      } else {
        debugPrint('⚠️ Unknown location string format');
        location = Point(coordinates: Position(0, 0));
      }
    } else if (locationData is Map && locationData['coordinates'] != null) {
      // GeoJSON format
      final coords = locationData['coordinates'] as List;
      location = Point(
        coordinates: Position(
          (coords[0] as num).toDouble(),
          (coords[1] as num).toDouble(),
        ),
      );
    } else {
      // Fallback to 0,0 if location parsing fails
      debugPrint('⚠️ Location data is null or unknown type');
      location = Point(coordinates: Position(0, 0));
    }

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
    debugPrint(
        '📍 fromJson: id=${json['id']}, weight=${json['total_weight_kg']}, counts=$pollutionCountsMap');

    return ReportEntity(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      orgId: json['org_id'] as String?,
      location: location,
      address: json['address'] as String?,
      pollutionType: pollutionType,
      severity: json['severity'] as int? ?? 3,
      status: status,
      notes: json['notes'] as String?,
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      reportedAt: DateTime.parse(json['reported_at'] as String),
      imageUrls:
          (json['image_urls'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      city: json['city'] as String?,
      country: json['country'] as String?,
      totalWeightKg: (json['total_weight_kg'] as num?)?.toDouble(),
      pollutionCounts: pollutionCountsMap,
      xpEarned: (json['xp_earned'] as num?)?.toInt(),
    );
  }
}
