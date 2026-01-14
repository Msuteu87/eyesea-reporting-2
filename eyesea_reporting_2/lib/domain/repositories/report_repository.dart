import 'dart:io';
import '../entities/report.dart';

/// Abstract repository for report-related operations.
abstract class ReportRepository {
  /// Fetches all reports from the database.
  Future<List<ReportEntity>> fetchReports();

  /// Creates a new pollution report with an attached image.
  Future<void> createReport({
    required ReportEntity report,
    required File imageFile,
  });

  /// Fetch reports within a bounding box with optional delta sync.
  Future<List<Map<String, dynamic>>> fetchReportsInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    int limit = 500,
    DateTime? updatedSince,
    List<String>? statuses,
  });

  /// Fetch clustered reports for efficient map rendering at low zoom levels.
  Future<List<Map<String, dynamic>>> fetchClusteredReports({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    required int zoomLevel,
    int limit = 500,
  });

  /// Fetch reports for a specific user with optional status filtering.
  Future<List<Map<String, dynamic>>> fetchUserReports({
    required String userId,
    String? status,
    int limit = 20,
    int offset = 0,
  });

  /// Mark a report as recovered (sets status to 'resolved').
  Future<void> markAsRecovered(String reportId);
}
