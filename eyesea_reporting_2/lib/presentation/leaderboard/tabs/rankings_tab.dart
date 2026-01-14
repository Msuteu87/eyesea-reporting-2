import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../providers/leaderboard_provider.dart';
import '../widgets/leaderboard_category_toggle.dart';
import '../widgets/leaderboard_empty_state.dart';
import '../widgets/leaderboard_list.dart';
import '../widgets/leaderboard_rank_card.dart';
import '../widgets/leaderboard_time_filter.dart';

/// Rankings tab showing full leaderboard list.
class RankingsTab extends StatelessWidget {
  const RankingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LeaderboardProvider>(
      builder: (context, provider, _) {
        return RefreshIndicator(
          onRefresh: provider.loadLeaderboard,
          child: CustomScrollView(
            slivers: [
              // Category toggle
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: LeaderboardCategoryToggle(
                    selected: provider.category,
                    onChanged: provider.setCategory,
                  ),
                ),
              ),

              // Time filter
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: LeaderboardTimeFilter(
                    selected: provider.timeFilter,
                    onChanged: provider.setTimeFilter,
                  ),
                ),
              ),

              // Loading state
              if (provider.isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )

              // Error state
              else if (provider.error != null)
                SliverFillRemaining(
                  child: LeaderboardEmptyState(
                    icon: LucideIcons.alertCircle,
                    title: 'Something went wrong',
                    subtitle: 'Tap to retry',
                    onRetry: provider.loadLeaderboard,
                  ),
                )

              // Empty state
              else if (provider.entries.isEmpty)
                const SliverFillRemaining(
                  child: LeaderboardEmptyState(
                    icon: LucideIcons.trophy,
                    title: 'No rankings yet',
                    subtitle: 'Be the first to contribute!',
                  ),
                )

              // Content
              else ...[
                // User's rank card (if applicable)
                if (provider.userInCurrentCategory && provider.userRank != null)
                  SliverToBoxAdapter(
                    child: LeaderboardRankCard(
                      rank: provider.userRank!,
                      category: provider.category,
                    ),
                  ),

                // Full leaderboard list (all entries)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: LeaderboardList(
                    entries: provider.entries,
                    category: provider.category,
                    startRank: 1,
                  ),
                ),

                // Bottom padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
