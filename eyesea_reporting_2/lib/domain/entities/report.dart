import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

enum PollutionType {
  plastic,
  oil,
  debris,
  sewage,
  fishing_gear, // maps to fishing_gear
  other,
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
  });
}
