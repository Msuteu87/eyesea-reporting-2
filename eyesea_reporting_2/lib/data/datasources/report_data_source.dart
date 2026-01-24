import 'dart:developer';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/exceptions.dart';
import '../../core/services/image_validation_service.dart';
import '../../core/utils/logger.dart';

/// Data source for report CRUD operations.
///
/// ## Security Note: Gamification Data
///
/// **Current:** XP, fraudScore, and pollutionCounts are calculated client-side
/// and sent to the server. This is acceptable because:
/// - RLS policies ensure users can only create reports for themselves
/// - Fraud detection flags suspicious reports for admin review
/// - XP caps prevent excessive gaming
///
/// **For production hardening:** Calculate XP and fraud scores server-side
/// using a Supabase Edge Function that re-runs the calculations on the AI
/// analysis data stored in the `ai_analysis` table.
class ReportDataSource {
  final SupabaseClient _supabase;

  ReportDataSource(this._supabase);

  /// Fetches image URLs for a single report and attaches them to the report map
  Future<void> _attachImagesToReport(Map<String, dynamic> report) async {
    final reportId = report['id'] as String?;
    if (reportId == null) return;

    try {
      final images = await _supabase
          .from('report_images')
          .select('storage_path, is_primary')
          .eq('report_id', reportId)
          .order('is_primary', ascending: false);

      report['image_urls'] = (images as List)
          .map((img) => img['storage_path'] as String?)
          .where((url) => url != null)
          .cast<String>()
          .toList();
    } catch (e) {
      AppLogger.warning('Failed to fetch images for report $reportId: $e');
      report['image_urls'] = <String>[];
    }
  }

  /// Attaches image URLs to a list of reports
  Future<void> _attachImagesToReports(
      List<Map<String, dynamic>> reports) async {
    for (final report in reports) {
      await _attachImagesToReport(report);
    }
  }

  Future<List<Map<String, dynamic>>> fetchReports() async {
    try {
      // Use RPC to get location as text (ST_AsText converts WKB to readable format)
      final response = await _supabase.rpc('get_reports_with_location');
      final reports = List<Map<String, dynamic>>.from(response);

      await _attachImagesToReports(reports);

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

  /// Fetch reports within a bounding box WITH images included (no N+1 queries).
  /// Supports delta sync via [updatedSince] parameter.
  /// Supports server-side status filtering via [statuses] parameter.
  Future<List<Map<String, dynamic>>> fetchReportsInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    int limit = 500,
    DateTime? updatedSince,
    List<String>? statuses, // Optional: filter by status server-side
  }) async {
    try {
      // Use the new optimized RPC that includes images (fixes N+1)
      final params = <String, dynamic>{
        'min_lng': minLng,
        'min_lat': minLat,
        'max_lng': maxLng,
        'max_lat': maxLat,
        'max_results': limit,
      };

      // Add delta sync parameter if provided
      if (updatedSince != null) {
        params['p_updated_since'] = updatedSince.toUtc().toIso8601String();
      }

      // Add status filter if provided (reduces network transfer)
      if (statuses != null && statuses.isNotEmpty) {
        params['p_statuses'] = statuses;
      }

      log('[ReportDataSource] Calling get_reports_in_bounds_with_images with bounds: ($minLat,$minLng) to ($maxLat,$maxLng), delta: ${updatedSince != null}');

      final response = await _supabase.rpc(
        'get_reports_in_bounds_with_images',
        params: params,
      );

      final reports = List<Map<String, dynamic>>.from(response);
      log('[ReportDataSource] Got ${reports.length} reports from get_reports_in_bounds_with_images');

      // Images already included - no additional queries needed!
      return reports;
    } catch (e) {
      log('[ReportDataSource] get_reports_in_bounds_with_images failed: $e, trying fallback');
      // Fallback to old RPC if new one doesn't exist yet
      try {
        final response = await _supabase.rpc('get_reports_in_bounds', params: {
          'min_lng': minLng,
          'min_lat': minLat,
          'max_lng': maxLng,
          'max_lat': maxLat,
          'max_results': limit,
        });

        final reports = List<Map<String, dynamic>>.from(response);
        log('[ReportDataSource] Fallback got ${reports.length} reports');
        await _attachImagesToReports(reports);
        return reports;
      } catch (e2) {
        log('[ReportDataSource] Fallback also failed: $e2');
        throw ServerException(message: e2.toString());
      }
    }
  }

  /// Fetch clustered reports for efficient map rendering at low zoom levels.
  /// At zoom >= 14, returns individual points.
  /// At zoom < 14, returns cluster centroids with point counts.
  Future<List<Map<String, dynamic>>> fetchClusteredReports({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    required int zoomLevel,
    int limit = 500,
  }) async {
    try {
      final response = await _supabase.rpc('get_clustered_reports', params: {
        'min_lng': minLng,
        'min_lat': minLat,
        'max_lng': maxLng,
        'max_lat': maxLat,
        'zoom_level': zoomLevel,
        'max_results': limit,
      });

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      // Fallback to regular bounds fetch if clustering RPC doesn't exist
      return fetchReportsInBounds(
        minLat: minLat,
        maxLat: maxLat,
        minLng: minLng,
        maxLng: maxLng,
        limit: limit,
      );
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
    // Validate image before upload (size and MIME type)
    final validation = ImageValidationService.validateReportImage(imageFile);
    if (!validation.isValid) {
      throw ValidationException(message: validation.errorMessage!);
    }

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

  /// Fetch lightweight heatmap points via RPC (deprecated - use fetchHeatmapGrid)
  Future<List<Map<String, dynamic>>> fetchHeatmapPoints() async {
    try {
      final response = await _supabase.rpc('get_heatmap_points');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      // If RPC fails or doesn't exist, log warning and return empty
      AppLogger.warning('Failed to fetch heatmap points: $e');
      return [];
    }
  }

  /// Fetch grid-aggregated heatmap data for global visualization.
  /// This ensures all regions are represented regardless of report density.
  /// [cellSize] controls grid resolution: 2.0 for global view, 0.5 for regional.
  Future<List<Map<String, dynamic>>> fetchHeatmapGrid({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    double cellSize = 2.0,
  }) async {
    try {
      log('[ReportDataSource] Calling get_heatmap_grid with cell_size=$cellSize');
      final response = await _supabase.rpc('get_heatmap_grid', params: {
        'min_lng': minLng,
        'min_lat': minLat,
        'max_lng': maxLng,
        'max_lat': maxLat,
        'cell_size': cellSize,
      });
      final results = List<Map<String, dynamic>>.from(response);
      log('[ReportDataSource] Got ${results.length} grid cells from get_heatmap_grid');
      return results;
    } catch (e) {
      log('[ReportDataSource] get_heatmap_grid failed: $e, falling back to fetchHeatmapPoints');
      // Fallback to old method if new RPC doesn't exist yet
      return fetchHeatmapPoints();
    }
  }
}
