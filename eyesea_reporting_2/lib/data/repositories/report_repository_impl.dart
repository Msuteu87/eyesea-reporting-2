import 'dart:io';
import '../../domain/entities/report.dart';
import '../../domain/repositories/report_repository.dart';
import '../datasources/report_data_source.dart';

class ReportRepositoryImpl implements ReportRepository {
  final ReportDataSource _dataSource;

  ReportRepositoryImpl(this._dataSource);

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
      // 'address': report.address, // Add if schema supports it or use metadata
    };

    final createdReport = await _dataSource.createReport(reportData);
    final reportId = createdReport['id'] as String;

    // 2. Upload Image
    final publicUrl =
        await _dataSource.uploadReportImage(report.userId, reportId, imageFile);

    // 3. Create Image Record
    await _dataSource.createReportImageRecord(reportId, publicUrl, true);
  }
}
