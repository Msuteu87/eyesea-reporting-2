import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../data/datasources/badge_data_source.dart';
import '../../domain/entities/badge.dart';
import '../providers/auth_provider.dart';

/// Leaderboard and Awards screen with tabbed interface.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.inkBlack : AppColors.culturedWhite,
      body: SafeArea(
        child: Column(
          children: [
            // Header with title
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Leaderboard',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.darkGunmetal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Compete & earn awards',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey[400] : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.electricNavy,
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: isDark
                    ? Colors.white.withValues(alpha: 0.6)
                    : Colors.black.withValues(alpha: 0.6),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.trophy, size: 18),
                        SizedBox(width: 8),
                        Text('Rankings'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.award, size: 18),
                        SizedBox(width: 8),
                        Text('Awards'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _LeaderboardTab(),
                  _AwardsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Leaderboard tab showing top users by XP.
class _LeaderboardTab extends StatefulWidget {
  const _LeaderboardTab();

  @override
  State<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<_LeaderboardTab> {
  List<Map<String, dynamic>> _leaderboard = [];
  UserStats? _userStats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final badgeDataSource = BadgeDataSource(Supabase.instance.client);
      final userId = authProvider.currentUser?.id;

      final results = await Future.wait([
        badgeDataSource.fetchLeaderboard(limit: 50),
        if (userId != null)
          badgeDataSource.fetchUserRank(
            userId,
            streakDays: authProvider.currentUser?.streakDays ?? 0,
          ),
      ]);

      if (mounted) {
        setState(() {
          _leaderboard = results[0] as List<Map<String, dynamic>>;
          if (results.length > 1) {
            _userStats = results[1] as UserStats;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = context.read<AuthProvider>().currentUser?.id;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.alertCircle, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Failed to load leaderboard',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadLeaderboard,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLeaderboard,
      child: CustomScrollView(
        slivers: [
          // User's current rank card
          if (_userStats != null && _userStats!.rank > 0)
            SliverToBoxAdapter(
              child: _buildUserRankCard(isDark),
            ),

          // Leaderboard list
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: _leaderboard.isEmpty
                ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.trophy,
                              size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            'No rankings yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Be the first to submit a report!',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final user = _leaderboard[index];
                        final isCurrentUser = user['user_id'] == currentUserId;
                        return _buildLeaderboardItem(
                          user,
                          index + 1,
                          isCurrentUser,
                          isDark,
                        );
                      },
                      childCount: _leaderboard.length,
                    ),
                  ),
          ),

          // Bottom padding for nav bar
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }

  Widget _buildUserRankCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.electricNavy,
            AppColors.deepIndigo,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.electricNavy.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#${_userStats!.rank}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Rank',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_userStats!.totalXp} XP',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Reports count
          Column(
            children: [
              const Icon(LucideIcons.fileCheck, color: Colors.white70, size: 20),
              const SizedBox(height: 4),
              Text(
                '${_userStats!.reportsCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Reports',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardItem(
    Map<String, dynamic> user,
    int rank,
    bool isCurrentUser,
    bool isDark,
  ) {
    final displayName = user['display_name'] as String? ?? 'Anonymous';
    final totalXp = (user['total_xp'] as num?)?.toInt() ?? 0;
    final reportsCount = (user['reports_count'] as num?)?.toInt() ?? 0;
    final avatarUrl = user['avatar_url'] as String?;

    Color? rankColor;
    IconData? rankIcon;
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700); // Gold
      rankIcon = LucideIcons.crown;
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Silver
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32); // Bronze
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppColors.electricNavy.withValues(alpha: 0.1)
            : (isDark ? AppColors.darkSurface : AppColors.pureWhite),
        borderRadius: BorderRadius.circular(16),
        border: isCurrentUser
            ? Border.all(color: AppColors.electricNavy, width: 2)
            : null,
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 40,
            child: rank <= 3
                ? Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: rankColor?.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: rankIcon != null
                          ? Icon(rankIcon, color: rankColor, size: 18)
                          : Text(
                              '$rank',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: rankColor,
                              ),
                            ),
                    ),
                  )
                : Text(
                    '$rank',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),
          const SizedBox(width: 12),

          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.electricNavy.withValues(alpha: 0.2),
            backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: AppColors.electricNavy,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // Name and reports
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$reportsCount reports',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),

          // XP
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.electricNavy.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$totalXp XP',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.electricNavy,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Awards tab showing badges earned and locked.
class _AwardsTab extends StatefulWidget {
  const _AwardsTab();

  @override
  State<_AwardsTab> createState() => _AwardsTabState();
}

class _AwardsTabState extends State<_AwardsTab> {
  List<BadgeEntity> _badges = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final badgeDataSource = BadgeDataSource(Supabase.instance.client);
      final userId = authProvider.currentUser?.id;

      if (userId == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final badges = await badgeDataSource.fetchBadgesWithStatus(userId);

      if (mounted) {
        setState(() {
          _badges = badges;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.alertCircle, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Failed to load awards',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadBadges,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final earnedBadges = _badges.where((b) => b.isEarned).toList();
    final lockedBadges = _badges.where((b) => !b.isEarned).toList();

    return RefreshIndicator(
      onRefresh: _loadBadges,
      child: _badges.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.award, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No awards available',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start reporting to earn badges!',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Earned section
                if (earnedBadges.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Earned',
                    earnedBadges.length,
                    LucideIcons.checkCircle,
                    Colors.green,
                    isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildBadgeGrid(earnedBadges, isDark),
                  const SizedBox(height: 24),
                ],

                // Locked section
                if (lockedBadges.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Locked',
                    lockedBadges.length,
                    LucideIcons.lock,
                    Colors.grey,
                    isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildBadgeGrid(lockedBadges, isDark),
                ],

                // Bottom padding for nav bar
                const SizedBox(height: 100),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    int count,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeGrid(List<BadgeEntity> badges, bool isDark) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        return _buildBadgeCard(badges[index], isDark);
      },
    );
  }

  Widget _buildBadgeCard(BadgeEntity badge, bool isDark) {
    final iconData = _getIconData(badge.icon);

    return GestureDetector(
      onTap: () => _showBadgeDetails(badge),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
          borderRadius: BorderRadius.circular(16),
          border: badge.isEarned
              ? Border.all(color: badge.color.withValues(alpha: 0.5), width: 2)
              : null,
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Badge icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: badge.isEarned
                    ? badge.color.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconData,
                color: badge.isEarned ? badge.color : Colors.grey,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            // Badge name
            Text(
              badge.name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: badge.isEarned
                    ? (isDark ? Colors.white : Colors.black87)
                    : Colors.grey,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            // Lock icon for locked badges
            if (!badge.isEarned) ...[
              const SizedBox(height: 4),
              Icon(LucideIcons.lock, size: 12, color: Colors.grey[400]),
            ],
          ],
        ),
      ),
    );
  }

  void _showBadgeDetails(BadgeEntity badge) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconData = _getIconData(badge.icon);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Badge icon large
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: badge.isEarned
                    ? badge.color.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconData,
                color: badge.isEarned ? badge.color : Colors.grey,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            // Name
            Text(
              badge.name,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            if (badge.description != null) ...[
              const SizedBox(height: 8),
              Text(
                badge.description!,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            // Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: badge.isEarned
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    badge.isEarned ? LucideIcons.checkCircle : LucideIcons.lock,
                    color: badge.isEarned ? Colors.green : Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    badge.isEarned
                        ? 'Earned ${_formatDate(badge.earnedAt)}'
                        : _getRequirementText(badge),
                    style: TextStyle(
                      color: badge.isEarned ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getRequirementText(BadgeEntity badge) {
    if (badge.thresholdType == null || badge.thresholdValue == null) {
      return 'Keep reporting to unlock!';
    }
    switch (badge.thresholdType) {
      case 'reports_count':
        return 'Submit ${badge.thresholdValue} reports';
      case 'streak_days':
        return '${badge.thresholdValue} day streak';
      default:
        return 'Keep reporting to unlock!';
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'award':
        return LucideIcons.award;
      case 'star':
        return LucideIcons.star;
      case 'trophy':
        return LucideIcons.trophy;
      case 'medal':
        return LucideIcons.medal;
      case 'crown':
        return LucideIcons.crown;
      case 'zap':
        return LucideIcons.zap;
      case 'flame':
        return LucideIcons.flame;
      case 'target':
        return LucideIcons.target;
      case 'rocket':
        return LucideIcons.rocket;
      case 'heart':
        return LucideIcons.heart;
      case 'shield':
        return LucideIcons.shield;
      case 'anchor':
        return LucideIcons.anchor;
      case 'compass':
        return LucideIcons.compass;
      case 'waves':
        return LucideIcons.waves;
      case 'fish':
        return LucideIcons.fish;
      case 'camera':
        return LucideIcons.camera;
      default:
        return LucideIcons.award;
    }
  }
}
