import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/exceptions.dart';

class SupabaseDataSource {
  final SupabaseClient supabase;

  SupabaseDataSource(this.supabase);

  Future<List<Map<String, dynamic>>> fetchReports() async {
    try {
      final response = await supabase.from('reports').select();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  Future<Map<String, dynamic>> createReport(Map<String, dynamic> data) async {
    try {
      final response = await supabase.from('reports').insert(data).select().single();
      return response;
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  Future<void> deleteReport(String id) async {
    try {
      await supabase.from('reports').delete().eq('id', id);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
