import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/leaderboard_data_source.dart';
import '../../providers/leaderboard_provider.dart';
import '../widgets/leaderboard_category_toggle.dart';
import '../widgets/leaderboard_empty_state.dart';
import '../widgets/leaderboard_podium.dart';
import '../widgets/leaderboard_time_filter.dart';

/// Awards tab showing top 3 podium.
class AwardsTab extends StatelessWidget {
  const AwardsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LeaderboardProvider>(
      builder: (context, provider, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

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

              // Content
              else ...[
                // Top 3 Spotlight header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.award,
                          size: 20,
                          color: isDark ? Colors.white70 : AppColors.coolGray,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Top 3 ${_getCategoryName(provider.category)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color:
                                isDark ? Colors.white : AppColors.darkGunmetal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Podium for top 3
                if (provider.podiumEntries.isNotEmpty)
                  SliverToBoxAdapter(
                    child: LeaderboardPodium(
                      entries: provider.podiumEntries,
                      category: provider.category,
                    ),
                  )
                else
                  const SliverFillRemaining(
                    child: LeaderboardEmptyState(
                      icon: LucideIcons.trophy,
                      title: 'No rankings yet',
                      subtitle: 'Start reporting to climb the ranks!',
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

  String _getCategoryName(LeaderboardCategory category) {
    return switch (category) {
      LeaderboardCategory.users => 'Users',
      LeaderboardCategory.organizations => 'Organizations',
      LeaderboardCategory.vessels => 'Ships',
    };
  }
}
