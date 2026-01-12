class VesselEntity {
  final String id;
  final String name;
  final String? imoNumber;
  final String? mmsi;
  final String? flagState;
  final String? orgId;

  const VesselEntity({
    required this.id,
    required this.name,
    this.imoNumber,
    this.mmsi,
    this.flagState,
    this.orgId,
  });
}
