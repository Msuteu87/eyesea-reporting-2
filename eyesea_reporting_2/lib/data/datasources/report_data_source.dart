import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/exceptions.dart';

/// Data source for report CRUD operations.
class ReportDataSource {
  final SupabaseClient _supabase;

  ReportDataSource(this._supabase);

  Future<List<Map<String, dynamic>>> fetchReports() async {
    try {
      // Use RPC to get location as text (ST_AsText converts WKB to readable format)
      final response = await _supabase.rpc('get_reports_with_location');
      final reports = List<Map<String, dynamic>>.from(response);

      // Fetch images for all reports and attach to each report
      for (final report in reports) {
        final reportId = report['id'] as String?;
        if (reportId != null) {
          try {
            final images = await _supabase
                .from('report_images')
                .select('storage_path, is_primary')
                .eq('report_id', reportId)
                .order('is_primary', ascending: false);

            final imageUrls = (images as List)
                .map((img) => img['storage_path'] as String?)
                .where((url) => url != null)
                .cast<String>()
                .toList();

            report['image_urls'] = imageUrls;
          } catch (_) {
            report['image_urls'] = <String>[];
          }
        }
      }

      return reports;
    } catch (e) {
      // Fallback to regular select if RPC doesn't exist
      try {
        final response = await _supabase.from('reports').select();
        return List<Map<String, dynamic>>.from(response);
      } catch (e2) {
        throw ServerException(message: e2.toString());
      }
    }
  }

  /// Fetch reports within a bounding box using PostGIS server-side filtering
  Future<List<Map<String, dynamic>>> fetchReportsInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    int limit = 500,
  }) async {
    try {
      final response = await _supabase.rpc('get_reports_in_bounds', params: {
        'min_lng': minLng,
        'min_lat': minLat,
        'max_lng': maxLng,
        'max_lat': maxLat,
        'max_results': limit,
      });

      final reports = List<Map<String, dynamic>>.from(response);

      // Fetch images for all reports and attach to each report
      for (final report in reports) {
        final reportId = report['id'] as String?;
        if (reportId != null) {
          try {
            final images = await _supabase
                .from('report_images')
                .select('storage_path, is_primary')
                .eq('report_id', reportId)
                .order('is_primary', ascending: false);

            final imageUrls = (images as List)
                .map((img) => img['storage_path'] as String?)
                .where((url) => url != null)
                .cast<String>()
                .toList();

            report['image_urls'] = imageUrls;
          } catch (_) {
            report['image_urls'] = <String>[];
          }
        }
      }

      return reports;
    } catch (e) {
      // Fallback to client-side filtering if RPC doesn't exist yet
      final allReports = await fetchReports();

      return allReports
          .where((report) {
            final location = report['location'] as String?;
            if (location == null) return false;

            final match =
                RegExp(r'POINT\(([-\d.]+) ([-\d.]+)\)').firstMatch(location);
            if (match == null) return false;

            final lng = double.tryParse(match.group(1) ?? '') ?? 0;
            final lat = double.tryParse(match.group(2) ?? '') ?? 0;

            return lat >= minLat &&
                lat <= maxLat &&
                lng >= minLng &&
                lng <= maxLng;
          })
          .take(limit)
          .toList();
    }
  }

  /// Fetch reports for a specific user with optional status filtering
  Future<List<Map<String, dynamic>>> fetchUserReports({
    required String userId,
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase.rpc('get_user_reports', params: {
        'p_user_id': userId,
        'p_status': status,
        'p_limit': limit,
        'p_offset': offset,
      });

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

  /// Mark a report as recovered (sets status to 'resolved')
  Future<void> markAsRecovered(String reportId) async {
    try {
      await _supabase.from('reports').update({
        'status': 'resolved',
        'resolved_at': DateTime.now().toIso8601String(),
      }).eq('id', reportId);
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

  /// Create AI analysis record for a report
  Future<void> createAIAnalysisRecord({
    required String reportId,
    required List<String> sceneLabels,
    required Map<String, int> pollutionTypeCounts,
    required int peopleCount,
    double? confidence,
  }) async {
    try {
      await _supabase.from('ai_analysis').insert({
        'report_id': reportId,
        'scene_labels': sceneLabels,
        'pollution_type_counts': pollutionTypeCounts,
        'people_count': peopleCount,
        'confidence': confidence,
        'analyzed_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
