import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/exceptions.dart';

/// Data source for report CRUD operations.
class ReportDataSource {
  final SupabaseClient _supabase;

  ReportDataSource(this._supabase);

  Future<List<Map<String, dynamic>>> fetchReports() async {
    try {
      final response = await _supabase.from('reports').select();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  Future<Map<String, dynamic>> createReport(Map<String, dynamic> data) async {
    try {
      final response =
          await _supabase.from('reports').insert(data).select().single();
      return response;
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  Future<void> deleteReport(String id) async {
    try {
      await _supabase.from('reports').delete().eq('id', id);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  Future<Map<String, dynamic>> updateReport(
      String id, Map<String, dynamic> data) async {
    try {
      final response = await _supabase
          .from('reports')
          .update(data)
          .eq('id', id)
          .select()
          .single();
      return response;
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  Future<String> uploadReportImage(
      String userId, String reportId, File imageFile) async {
    final fileName = '${DateTime.now().toIso8601String()}.jpg';
    final path = '$userId/$reportId/$fileName';

    await _supabase.storage.from('report-images').upload(path, imageFile);

    final publicUrl =
        _supabase.storage.from('report-images').getPublicUrl(path);
    return publicUrl;
  }

  Future<void> createReportImageRecord(
      String reportId, String storagePath, bool isPrimary) async {
    try {
      await _supabase.from('report_images').insert({
        'report_id': reportId,
        'storage_path': storagePath,
        'is_primary': isPrimary,
      });
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
