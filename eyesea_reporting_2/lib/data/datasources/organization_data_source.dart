import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/organization.dart';
import '../../domain/entities/vessel.dart';

class OrganizationDataSource {
  final SupabaseClient _supabaseClient;

  OrganizationDataSource(this._supabaseClient);

  Future<List<OrganizationEntity>> fetchShippingCompanies() async {
    try {
      final data = await _supabaseClient
          .from('organizations')
          .select()
          .eq('org_type', 'shipping_company')
          .eq('verified', true); // Only verified for now

      return (data as List).map((json) => _mapOrganization(json)).toList();
    } catch (e) {
      AppLogger.error('Error fetching shipping companies', e);
      throw Exception('Failed to fetch shipping companies');
    }
  }

  Future<List<VesselEntity>> fetchVessels(String orgId) async {
    try {
      final data =
          await _supabaseClient.from('vessels').select().eq('org_id', orgId);

      return (data as List).map((json) => _mapVessel(json)).toList();
    } catch (e) {
      AppLogger.error('Error fetching vessels for org: $orgId', e);
      throw Exception('Failed to fetch vessels');
    }
  }

  Future<List<OrganizationEntity>> searchOrganizations(String query) async {
    try {
      final data = await _supabaseClient
          .from('organizations')
          .select()
          .ilike('name', '%$query%')
          .eq('verified', true)
          .limit(10);

      return (data as List).map((json) => _mapOrganization(json)).toList();
    } catch (e) {
      AppLogger.error('Error searching organizations: $query', e);
      throw Exception('Failed to search organizations');
    }
  }

  // Mappers
  OrganizationEntity _mapOrganization(Map<String, dynamic> json) {
    return OrganizationEntity(
      id: json['id'],
      name: json['name'],
      logoUrl: json['logo_url'],
      country: json['country'],
      type: OrganizationEntity.parseType(json['org_type']),
      verified: json['verified'] ?? false,
    );
  }

  VesselEntity _mapVessel(Map<String, dynamic> json) {
    return VesselEntity(
      id: json['id'],
      name: json['name'],
      imoNumber: json['imo_number'],
      mmsi: json['mmsi'],
      flagState: json['flag_state'],
      orgId: json['org_id'],
    );
  }
}
