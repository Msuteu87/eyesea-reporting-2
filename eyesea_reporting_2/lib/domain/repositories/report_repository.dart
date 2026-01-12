import 'dart:io';
import '../entities/report.dart';

/// Abstract repository for report-related operations.
abstract class ReportRepository {
  /// Creates a new pollution report with an attached image.
  Future<void> createReport({
    required ReportEntity report,
    required File imageFile,
  });
}
