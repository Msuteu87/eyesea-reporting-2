enum UserRole {
  volunteer,
  ambassador,
  admin,
  seafarer,
  eyeseaRep,
}

class UserEntity {
  final String id;
  final String email;

  final String? displayName;
  final String? avatarUrl;
  final String? country;
  final String? city;
  final UserRole role;
  final int reportsCount;
  final int streakDays;

  // Organization Data
  final String? orgName;
  final String? orgId;
  final String? orgLogoUrl;

  // Seafarer Data
  final String? currentVesselId;
  final String? currentVesselName;

  // Ambassador Data
  final String? ambassadorRegionCountry;
  final String? ambassadorRegionName;

  const UserEntity({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
    this.country,
    this.city,
    this.role = UserRole.volunteer,
    this.reportsCount = 0,
    this.streakDays = 0,
    this.orgName,
    this.orgId,
    this.orgLogoUrl,
    this.currentVesselId,
    this.currentVesselName,
    this.ambassadorRegionCountry,
    this.ambassadorRegionName,
  });

  UserEntity copyWith({
    String? displayName,
    String? avatarUrl,
    String? country,
    String? city,
    UserRole? role,
    int? reportsCount,
    int? streakDays,
    String? orgName,
    String? orgId,
    String? orgLogoUrl,
    String? currentVesselId,
    String? currentVesselName,
    String? ambassadorRegionCountry,
    String? ambassadorRegionName,
  }) {
    return UserEntity(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      country: country ?? this.country,
      city: city ?? this.city,
      role: role ?? this.role,
      reportsCount: reportsCount ?? this.reportsCount,
      streakDays: streakDays ?? this.streakDays,
      orgName: orgName ?? this.orgName,
      orgId: orgId ?? this.orgId,
      orgLogoUrl: orgLogoUrl ?? this.orgLogoUrl,
      currentVesselId: currentVesselId ?? this.currentVesselId,
      currentVesselName: currentVesselName ?? this.currentVesselName,
      ambassadorRegionCountry:
          ambassadorRegionCountry ?? this.ambassadorRegionCountry,
      ambassadorRegionName: ambassadorRegionName ?? this.ambassadorRegionName,
    );
  }

  // Helper to check role from string (for DB mapping)
  static UserRole parseRole(String? roleStr) {
    switch (roleStr) {
      case 'ambassador':
        return UserRole.ambassador;
      case 'admin':
        return UserRole.admin;
      case 'seafarer':
        return UserRole.seafarer;
      case 'eyesea_rep':
        return UserRole.eyeseaRep;
      default:
        return UserRole.volunteer;
    }
  }
}
