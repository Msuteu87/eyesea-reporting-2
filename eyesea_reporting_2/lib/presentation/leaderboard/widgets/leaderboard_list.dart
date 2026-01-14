import 'package:flutter/material.dart';

import '../../../data/datasources/leaderboard_data_source.dart';
import '../../../domain/entities/leaderboard_entry.dart';
import 'leaderboard_list_item.dart';

/// Sliver list of leaderboard entries.
class LeaderboardList extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  final LeaderboardCategory category;
  final int startRank;
  final String? currentUserId;

  const LeaderboardList({
    super.key,
    required this.entries,
    required this.category,
    this.startRank = 4,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final entry = entries[index];
          final isCurrentUser =
              currentUserId != null && entry.id == currentUserId;

          return LeaderboardListItem(
            entry: entry,
            category: category,
            isCurrentUser: isCurrentUser,
          );
        },
        childCount: entries.length,
      ),
    );
  }
}
