import '../entities/organization.dart';
import '../entities/vessel.dart';

/// Repository for fetching organization and vessel data.
abstract class OrganizationRepository {
  /// Fetches all verified organizations (for Volunteers - optional selection).
  Future<List<OrganizationEntity>> fetchAllOrganizations();

  /// Fetches verified shipping companies (for Seafarers - required selection).
  Future<List<OrganizationEntity>> fetchShippingCompanies();

  /// Fetches vessels belonging to a specific organization.
  Future<List<VesselEntity>> fetchVessels(String orgId);

  /// Search for an organization by name.
  Future<List<OrganizationEntity>> searchOrganizations(String query);
}
