import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/event.dart';
import '../../domain/entities/unified_feed_item.dart';
import '../providers/auth_provider.dart';
import '../providers/social_feed_provider.dart';
import '../events/widgets/event_detail_modal.dart';
import 'widgets/feed_card.dart';
import 'widgets/event_feed_card.dart';
import 'widgets/feed_filter_control.dart';
import 'widgets/offline_banner.dart';

/// Social feed screen showing latest pollution reports with Instagram-style layout
class SocialFeedScreen extends StatefulWidget {
  const SocialFeedScreen({super.key});

  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFeed();
    });
  }

  void _showEventDetails(BuildContext context, EventFeedItem item) {
    // Convert EventFeedItem to EventEntity for the detail modal
    final event = EventEntity(
      id: item.id,
      organizerId: item.userId ?? '',
      organizerName: item.displayName ?? 'Anonymous',
      organizerAvatar: item.avatarUrl,
      title: item.title,
      description: item.description ?? '',
      address: item.address,
      startTime: item.startTime,
      endTime: item.endTime ?? item.startTime.add(const Duration(hours: 2)),
      createdAt: item.createdAt,
      maxAttendees: item.maxAttendees,
      attendeeCount: item.attendeeCount,
      isAttending: item.userHasJoined,
      status: item.status,
    );
    EventDetailModal.show(context, event);
  }

  Future<void> _initializeFeed() async {
    final auth = context.read<AuthProvider>();
    final feed = context.read<SocialFeedProvider>();

    feed.setCurrentUser(
      auth.currentUser?.id,
      auth.currentUser?.country,
      auth.currentUser?.city,
    );

    // Initialize location for proximity-based filtering (non-blocking)
    await feed.initializeLocation();
    if (mounted) {
      feed.loadFeed(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.inkBlack : AppColors.culturedWhite,
      body: SafeArea(
        child: Consumer<SocialFeedProvider>(
          builder: (context, provider, _) {
            return Column(
              children: [
                // Custom app bar
                _buildAppBar(context, isDark),

                // Offline banner
                if (provider.isOffline) const OfflineBanner(),

                // Filter control
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FeedFilterControl(
                    selected: provider.currentFilter,
                    onChanged: provider.setFilter,
                    countryName: provider.filterCountry,
                    cityName: provider.filterCity,
                  ),
                ),

                const SizedBox(height: 16),

                // Feed list
                Expanded(
                  child: _buildFeedContent(provider, isDark),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community Feed',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.darkGunmetal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'See what others are reporting',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          // Refresh button
          IconButton(
            onPressed: () {
              context.read<SocialFeedProvider>().loadFeed(refresh: true);
            },
            icon: Icon(
              LucideIcons.refreshCw,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedContent(SocialFeedProvider provider, bool isDark) {
    // Offline state
    if (provider.isOffline) {
      return _buildOfflineState(isDark);
    }

    // Loading state (initial load)
    if (provider.isLoading && provider.items.isEmpty) {
      return _buildLoadingState();
    }

    // Error state
    if (provider.error != null && provider.items.isEmpty) {
      return _buildErrorState(provider.error!, isDark);
    }

    // Empty state
    if (provider.items.isEmpty) {
      return _buildEmptyState(isDark);
    }

    // Feed list
    final currentUserId = context.read<AuthProvider>().currentUser?.id;

    return RefreshIndicator(
      onRefresh: () => provider.loadFeed(refresh: true),
      color: AppColors.oceanBlue,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: provider.items.length + (provider.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Load more trigger
          if (index >= provider.items.length) {
            provider.loadFeed();
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.oceanBlue,
                ),
              ),
            );
          }

          final item = provider.items[index];
          
          // Pattern matching for different item types
          if (item is ReportFeedItem) {
            return FeedCard(
              item: item,
              canThank: currentUserId != null && item.userId != currentUserId,
              onThankPressed: () => provider.toggleThank(item.id),
            );
          } else if (item is EventFeedItem) {
            return EventFeedCard(
              item: item,
              canJoin: provider.canJoin(item),
              onJoinPressed: () => provider.toggleJoinEvent(item.id),
              onTap: () => _showEventDetails(context, item),
            );
          }
          
          // Fallback (should never reach here)
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildOfflineState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.amberGlow.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.wifiOff,
                size: 48,
                color: AppColors.amberGlow,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "You're offline",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.inkBlack,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect to the internet to view the community feed and see the latest pollution reports.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.oceanBlue,
      ),
    );
  }

  Widget _buildErrorState(String error, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.punchRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.alertCircle,
                size: 48,
                color: AppColors.punchRed,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.inkBlack,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _initializeFeed,
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.oceanBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.oceanBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.image,
                size: 48,
                color: AppColors.oceanBlue,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No reports yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.inkBlack,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getEmptyStateMessage(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getEmptyStateMessage() {
    final provider = context.read<SocialFeedProvider>();
    switch (provider.currentFilter) {
      case FeedFilter.nearby:
        return 'No reports nearby yet. Expand your search or be the first to report!';
      case FeedFilter.city:
        return 'No reports in your city yet. Be the first to report pollution!';
      case FeedFilter.country:
        return 'No reports in your country yet. Help us map pollution in your area!';
      case FeedFilter.world:
        return 'No reports have been submitted yet. Start by capturing your first pollution sighting!';
    }
  }
}
