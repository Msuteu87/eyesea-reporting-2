/// Represents the current user's rank in a specific category (user, organization, or vessel).
class CategoryRank {
  final int rank;
  final String entityId;
  final String entityName;
  final int reportsCount;
  final int totalXp;
  final bool isMember;

  const CategoryRank({
    required this.rank,
    required this.entityId,
    required this.entityName,
    required this.reportsCount,
    required this.totalXp,
    required this.isMember,
  });

  factory CategoryRank.fromJson(Map<String, dynamic> json) {
    return CategoryRank(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      entityId: json['entity_id'] as String? ?? '',
      entityName: json['entity_name'] as String? ?? '',
      reportsCount: (json['reports_count'] as num?)?.toInt() ?? 0,
      totalXp: (json['total_xp'] as num?)?.toInt() ?? 0,
      isMember: json['is_member'] as bool? ?? false,
    );
  }

  static const empty = CategoryRank(
    rank: 0,
    entityId: '',
    entityName: '',
    reportsCount: 0,
    totalXp: 0,
    isMember: false,
  );

  bool get hasRank => rank > 0 && entityId.isNotEmpty;

  CategoryRank copyWith({
    int? rank,
    String? entityId,
    String? entityName,
    int? reportsCount,
    int? totalXp,
    bool? isMember,
  }) {
    return CategoryRank(
      rank: rank ?? this.rank,
      entityId: entityId ?? this.entityId,
      entityName: entityName ?? this.entityName,
      reportsCount: reportsCount ?? this.reportsCount,
      totalXp: totalXp ?? this.totalXp,
      isMember: isMember ?? this.isMember,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategoryRank &&
        other.rank == rank &&
        other.entityId == entityId;
  }

  @override
  int get hashCode => rank.hashCode ^ entityId.hashCode;
}
