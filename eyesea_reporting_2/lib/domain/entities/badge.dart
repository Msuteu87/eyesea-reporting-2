import 'package:flutter/material.dart';

/// Represents a badge/achievement that users can earn.
class BadgeEntity {
  final String id;
  final String badgeId;
  final String name;
  final String slug;
  final String icon;
  final String? description;
  final Color color;
  final DateTime? earnedAt;
  final bool isEarned;

  // For locked badges (showing what's needed)
  final String? thresholdType;
  final int? thresholdValue;

  const BadgeEntity({
    required this.id,
    required this.badgeId,
    required this.name,
    required this.slug,
    required this.icon,
    this.description,
    required this.color,
    this.earnedAt,
    this.isEarned = false,
    this.thresholdType,
    this.thresholdValue,
  });

  factory BadgeEntity.fromJson(Map<String, dynamic> json, {bool earned = true}) {
    return BadgeEntity(
      id: json['id']?.toString() ?? '',
      badgeId: json['badge_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      icon: json['icon'] as String? ?? 'award',
      description: json['description'] as String?,
      color: _parseColor(json['color'] as String?),
      earnedAt: json['earned_at'] != null
          ? DateTime.tryParse(json['earned_at'] as String)
          : null,
      isEarned: earned,
      thresholdType: json['threshold_type'] as String?,
      thresholdValue: json['threshold_value'] as int?,
    );
  }

  static Color _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) {
      return const Color(0xFF3B82F6); // Default blue
    }
    try {
      final hex = hexColor.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF3B82F6);
    }
  }

  BadgeEntity copyWith({
    String? id,
    String? badgeId,
    String? name,
    String? slug,
    String? icon,
    String? description,
    Color? color,
    DateTime? earnedAt,
    bool? isEarned,
    String? thresholdType,
    int? thresholdValue,
  }) {
    return BadgeEntity(
      id: id ?? this.id,
      badgeId: badgeId ?? this.badgeId,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      icon: icon ?? this.icon,
      description: description ?? this.description,
      color: color ?? this.color,
      earnedAt: earnedAt ?? this.earnedAt,
      isEarned: isEarned ?? this.isEarned,
      thresholdType: thresholdType ?? this.thresholdType,
      thresholdValue: thresholdValue ?? this.thresholdValue,
    );
  }
}

/// User stats including rank and XP.
class UserStats {
  final int rank;
  final int totalUsers;
  final int reportsCount;
  final int totalXp;
  final int streakDays;

  const UserStats({
    required this.rank,
    required this.totalUsers,
    required this.reportsCount,
    required this.totalXp,
    required this.streakDays,
  });

  factory UserStats.fromJson(Map<String, dynamic> json, {int streakDays = 0}) {
    return UserStats(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      totalUsers: (json['total_users'] as num?)?.toInt() ?? 0,
      reportsCount: (json['reports_count'] as num?)?.toInt() ?? 0,
      totalXp: (json['total_xp'] as num?)?.toInt() ?? 0,
      streakDays: streakDays,
    );
  }

  static const empty = UserStats(
    rank: 0,
    totalUsers: 0,
    reportsCount: 0,
    totalXp: 0,
    streakDays: 0,
  );
}
