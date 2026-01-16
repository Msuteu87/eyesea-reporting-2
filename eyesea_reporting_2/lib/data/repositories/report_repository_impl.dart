import 'dart:io';
import '../../core/utils/logger.dart';
import '../../domain/entities/report.dart';
import '../../domain/entities/heatmap_point.dart';
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
    final publicUrl = await _dataSource.uploadReportImage(
        report.userId ?? 'anonymous', reportId, imageFile);

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

  @override
  Future<List<HeatmapPoint>> fetchHeatmapPoints({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
    try {
      // Calculate appropriate cell size based on viewport span
      // Larger viewport = larger cells for performance
      // Smaller viewport = smaller cells for detail
      final latSpan = maxLat - minLat;
      final lngSpan = maxLng - minLng;
      final maxSpan = latSpan > lngSpan ? latSpan : lngSpan;

      double cellSize;
      if (maxSpan > 100) {
        // Global view: 3° cells (~300km)
        cellSize = 3.0;
      } else if (maxSpan > 50) {
        // Continental view: 2° cells (~200km)
        cellSize = 2.0;
      } else if (maxSpan > 20) {
        // Regional view: 1° cells (~100km)
        cellSize = 1.0;
      } else if (maxSpan > 5) {
        // Country view: 0.5° cells (~50km)
        cellSize = 0.5;
      } else {
        // City view: 0.2° cells (~20km)
        cellSize = 0.2;
      }

      AppLogger.info(
          'Fetching heatmap grid with cellSize=$cellSize for span=$maxSpan°');

      // Use grid aggregation for even coverage across all regions
      final gridData = await _dataSource.fetchHeatmapGrid(
        minLat: minLat,
        maxLat: maxLat,
        minLng: minLng,
        maxLng: maxLng,
        cellSize: cellSize,
      );

      return gridData.map((json) {
        return HeatmapPoint(
          // Use cell coordinates as ID (unique per grid cell)
          id: '${json['cell_lat']}_${json['cell_lng']}',
          latitude: (json['cell_lat'] as num).toDouble(),
          longitude: (json['cell_lng'] as num).toDouble(),
          // Weight from the aggregation (logarithmic scale based on report count)
          weight: (json['weight'] as num?)?.toDouble() ?? 0.5,
        );
      }).toList();
    } catch (e) {
      AppLogger.error('Error fetching heatmap points: $e');
      return [];
    }
  }
}
