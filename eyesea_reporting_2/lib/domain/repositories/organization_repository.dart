import '../entities/organization.dart';
import '../entities/vessel.dart';

/// Repository for fetching organization and vessel data.
abstract class OrganizationRepository {
  /// Fetches a list of verified shipping companies (or all suitable for Seafarers).
  Future<List<OrganizationEntity>> fetchShippingCompanies();

  /// Fetches vessels belonging to a specific organization.
  Future<List<VesselEntity>> fetchVessels(String orgId);

  /// Search for an organization by name.
  Future<List<OrganizationEntity>> searchOrganizations(String query);
}
