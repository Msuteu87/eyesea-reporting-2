import '../../domain/entities/organization.dart';
import '../../domain/entities/vessel.dart';
import '../../domain/repositories/organization_repository.dart';
import '../datasources/organization_data_source.dart';

class OrganizationRepositoryImpl implements OrganizationRepository {
  final OrganizationDataSource _dataSource;

  OrganizationRepositoryImpl(this._dataSource);

  @override
  Future<List<OrganizationEntity>> fetchAllOrganizations() async {
    return await _dataSource.fetchAllOrganizations();
  }

  @override
  Future<List<OrganizationEntity>> fetchShippingCompanies() async {
    return await _dataSource.fetchShippingCompanies();
  }

  @override
  Future<List<VesselEntity>> fetchVessels(String orgId) async {
    return await _dataSource.fetchVessels(orgId);
  }

  @override
  Future<List<OrganizationEntity>> searchOrganizations(String query) async {
    return await _dataSource.searchOrganizations(query);
  }
}
