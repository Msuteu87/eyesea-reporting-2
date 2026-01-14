import 'dart:io';
import '../../core/utils/logger.dart';
import '../../domain/entities/report.dart';
import '../../domain/repositories/report_repository.dart';
import '../datasources/report_data_source.dart';

class ReportRepositoryImpl implements ReportRepository {
  final ReportDataSource _dataSource;

  ReportRepositoryImpl(this._dataSource);

  @override
  Future<List<ReportEntity>> fetchReports() async {
    try {
      final data = await _dataSource.fetchReports();
      return data.map((json) => ReportEntity.fromJson(json)).toList();
    } catch (e) {
      AppLogger.error('Error fetching reports: $e');
      rethrow; // Let callers handle the error and distinguish from empty list
    }
  }

  @override
  Future<void> createReport({
    required ReportEntity report,
    required File imageFile,
  }) async {
    // 1. Create Report Record
    final reportData = {
      'user_id': report.userId,
      'pollution_type': report.pollutionType.name,
      'severity': report.severity,
      'status': report.status.name,
      'location':
          'POINT(${report.location.coordinates.lng} ${report.location.coordinates.lat})',
      'notes': report.notes,
      'is_anonymous': report.isAnonymous,
      'city': report.city,
      'country': report.country,
    };

    final createdReport = await _dataSource.createReport(reportData);
    final reportId = createdReport['id'] as String;

    // 2. Upload Image (userId should always exist for app submissions, fallback to 'anonymous')
    final publicUrl =
        await _dataSource.uploadReportImage(report.userId ?? 'anonymous', reportId, imageFile);

    // 3. Create Image Record
    await _dataSource.createReportImageRecord(reportId, publicUrl, true);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchReportsInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    int limit = 500,
    DateTime? updatedSince,
    List<String>? statuses,
  }) {
    return _dataSource.fetchReportsInBounds(
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
      limit: limit,
      updatedSince: updatedSince,
      statuses: statuses,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> fetchClusteredReports({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    required int zoomLevel,
    int limit = 500,
  }) {
    return _dataSource.fetchClusteredReports(
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
      zoomLevel: zoomLevel,
      limit: limit,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> fetchUserReports({
    required String userId,
    String? status,
    int limit = 20,
    int offset = 0,
  }) {
    return _dataSource.fetchUserReports(
      userId: userId,
      status: status,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<void> markAsRecovered(String reportId) {
    return _dataSource.markAsRecovered(reportId);
  }
}
