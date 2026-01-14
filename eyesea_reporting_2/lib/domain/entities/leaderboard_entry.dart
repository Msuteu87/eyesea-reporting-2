/// Represents a single entry in any leaderboard category (user, organization, or vessel).
class LeaderboardEntry {
  final int rank;
  final String id;
  final String name;
  final String? avatarUrl; // For users
  final String? logoUrl; // For organizations
  final String? flagState; // For vessels
  final String? subtitle; // Organization name for vessels, country for orgs
  final int reportsCount;
  final int totalXp;
  final int? memberCount; // For organizations

  const LeaderboardEntry({
    required this.rank,
    required this.id,
    required this.name,
    this.avatarUrl,
    this.logoUrl,
    this.flagState,
    this.subtitle,
    required this.reportsCount,
    required this.totalXp,
    this.memberCount,
  });

  factory LeaderboardEntry.fromUserJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: (json['rank'] as num).toInt(),
      id: json['user_id'] as String,
      name: json['display_name'] as String? ?? 'Anonymous',
      avatarUrl: json['avatar_url'] as String?,
      reportsCount: (json['reports_count'] as num).toInt(),
      totalXp: (json['total_xp'] as num).toInt(),
    );
  }

  factory LeaderboardEntry.fromOrgJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: (json['rank'] as num).toInt(),
      id: json['org_id'] as String,
      name: json['org_name'] as String,
      logoUrl: json['logo_url'] as String?,
      subtitle: json['country'] as String?,
      reportsCount: (json['reports_count'] as num).toInt(),
      totalXp: (json['total_xp'] as num).toInt(),
      memberCount: (json['member_count'] as num?)?.toInt(),
    );
  }

  factory LeaderboardEntry.fromVesselJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: (json['rank'] as num).toInt(),
      id: json['vessel_id'] as String,
      name: json['vessel_name'] as String,
      flagState: json['flag_state'] as String?,
      subtitle: json['org_name'] as String?,
      reportsCount: (json['reports_count'] as num).toInt(),
      totalXp: (json['total_xp'] as num).toInt(),
    );
  }

  LeaderboardEntry copyWith({
    int? rank,
    String? id,
    String? name,
    String? avatarUrl,
    String? logoUrl,
    String? flagState,
    String? subtitle,
    int? reportsCount,
    int? totalXp,
    int? memberCount,
  }) {
    return LeaderboardEntry(
      rank: rank ?? this.rank,
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      logoUrl: logoUrl ?? this.logoUrl,
      flagState: flagState ?? this.flagState,
      subtitle: subtitle ?? this.subtitle,
      reportsCount: reportsCount ?? this.reportsCount,
      totalXp: totalXp ?? this.totalXp,
      memberCount: memberCount ?? this.memberCount,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LeaderboardEntry && other.id == id && other.rank == rank;
  }

  @override
  int get hashCode => id.hashCode ^ rank.hashCode;
}
