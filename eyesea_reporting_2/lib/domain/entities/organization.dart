enum OrganizationType {
  shippingCompany,
  shipManagement,
  ngo,
  other,
}

class OrganizationEntity {
  final String id;
  final String name;
  final String? logoUrl;
  final String? country;
  final OrganizationType type;
  final bool verified;

  const OrganizationEntity({
    required this.id,
    required this.name,
    this.logoUrl,
    this.country,
    this.type = OrganizationType.other,
    this.verified = false,
  });

  static OrganizationType parseType(String? typeStr) {
    switch (typeStr) {
      case 'shipping_company':
        return OrganizationType.shippingCompany;
      case 'ship_management':
        return OrganizationType.shipManagement;
      case 'ngo':
        return OrganizationType.ngo;
      default:
        return OrganizationType.other;
    }
  }
}
