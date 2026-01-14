import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/leaderboard_provider.dart';
import 'tabs/awards_tab.dart';
import 'tabs/rankings_tab.dart';

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

    // Initialize provider after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProvider();
    });
  }

  void _initializeProvider() {
    final authProvider = context.read<AuthProvider>();
    final leaderboardProvider = context.read<LeaderboardProvider>();

    leaderboardProvider.setCurrentUser(authProvider.currentUser?.id);
    leaderboardProvider.refresh();
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
                  RankingsTab(),
                  AwardsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
