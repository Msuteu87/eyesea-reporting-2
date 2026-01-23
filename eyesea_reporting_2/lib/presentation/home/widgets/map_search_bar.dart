import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/logger.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/report.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reports_map_provider.dart';
import '../../widgets/notification_panel.dart';

/// Floating search bar with integrated filter button for Google Maps-like UX.
/// Contains a location search field, filter toggle, and user avatar.
class MapSearchBar extends StatefulWidget {
  /// Callback when a location is selected from search results.
  /// Returns [latitude, longitude] coordinates.
  final void Function(double latitude, double longitude)? onLocationSelected;

  /// Callback when filter panel expands or collapses.
  /// Used by parent to adjust other UI elements positioning.
  final void Function(bool isExpanded)? onFiltersExpandedChanged;

  const MapSearchBar({
    super.key,
    this.onLocationSelected,
    this.onFiltersExpandedChanged,
  });

  @override
  State<MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends State<MapSearchBar>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSearching = false;
  List<GeocodingResult> _searchResults = [];
  bool _filtersExpanded = false;

  late AnimationController _filterAnimationController;
  late Animation<double> _filterExpandAnimation;

  @override
  void initState() {
    super.initState();
    _filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _filterExpandAnimation = CurvedAnimation(
      parent: _filterAnimationController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _filterAnimationController.dispose();
    super.dispose();
  }

  void _toggleFilters() {
    setState(() {
      _filtersExpanded = !_filtersExpanded;
      if (_filtersExpanded) {
        _filterAnimationController.forward();
      } else {
        _filterAnimationController.reverse();
      }
    });
    // Notify parent about filter expansion state
    widget.onFiltersExpandedChanged?.call(_filtersExpanded);
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      // Use Mapbox Geocoding API
      // For now, we'll use a simple implementation
      // In production, you'd want to use the Mapbox Search SDK or REST API
      final results = await _searchLocations(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      AppLogger.error('Search error: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  /// Search locations using Mapbox Geocoding API
  Future<List<GeocodingResult>> _searchLocations(String query) async {
    return GeocodingService.search(query, limit: 5);
  }

  void _onResultSelected(GeocodingResult result) {
    _searchController.text = result.placeName;
    _focusNode.unfocus();
    setState(() => _searchResults = []);
    widget.onLocationSelected?.call(result.latitude, result.longitude);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchResults = []);
  }

  Widget _buildFilterChips(
      BuildContext context, ReportsMapProvider provider, bool isDark) {
    final visibleStatuses = provider.visibleStatuses;
    final isMyReports = provider.showOnlyMyReports;
    final isActiveSelected = visibleStatuses.contains(ReportStatus.pending) ||
        visibleStatuses.contains(ReportStatus.verified);
    final isRecoveredSelected = visibleStatuses.contains(ReportStatus.resolved);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey[900]!.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // My Reports Chip
          _FilterChip(
            label: 'My Reports',
            icon: LucideIcons.user,
            isSelected: isMyReports,
            selectedColor: AppColors.electricNavy,
            isDark: isDark,
            onTap: () => provider.setShowOnlyMyReports(!isMyReports),
          ),
          const SizedBox(width: 8),

          // Active Reports Chip
          _FilterChip(
            label: 'Active',
            icon: LucideIcons.alertCircle,
            isSelected: isActiveSelected,
            selectedColor: const Color(0xFFEF4444),
            isDark: isDark,
            onTap: () {
              final newStatuses = Set<ReportStatus>.from(visibleStatuses);
              if (isActiveSelected) {
                newStatuses.remove(ReportStatus.pending);
                newStatuses.remove(ReportStatus.verified);
              } else {
                newStatuses.add(ReportStatus.pending);
                newStatuses.add(ReportStatus.verified);
              }
              provider.setVisibleStatuses(newStatuses);
            },
          ),
          const SizedBox(width: 8),

          // Recovered Reports Chip
          _FilterChip(
            label: 'Recovered',
            icon: LucideIcons.checkCircle2,
            isSelected: isRecoveredSelected,
            selectedColor: AppColors.emerald,
            isDark: isDark,
            onTap: () {
              final newStatuses = Set<ReportStatus>.from(visibleStatuses);
              if (isRecoveredSelected) {
                newStatuses.remove(ReportStatus.resolved);
              } else {
                newStatuses.add(ReportStatus.resolved);
              }
              provider.setVisibleStatuses(newStatuses);
            },
          ),
        ],
      ),
    );
  }

  /// Count of active filters for badge display
  int _getActiveFilterCount(ReportsMapProvider provider) {
    int count = 0;
    if (provider.showOnlyMyReports) count++;
    // Check if not showing all statuses (default is all active)
    final visibleStatuses = provider.visibleStatuses;
    final hasActive = visibleStatuses.contains(ReportStatus.pending) ||
        visibleStatuses.contains(ReportStatus.verified);
    final hasRecovered = visibleStatuses.contains(ReportStatus.resolved);
    // Count as active filter if either is toggled off from default
    if (!hasActive) count++;
    if (hasRecovered) count++; // Recovered is off by default, so count when on
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final provider = context.watch<ReportsMapProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeFilterCount = _getActiveFilterCount(provider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main search bar container
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.grey[900]!.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Row(
                children: [
                  // Search icon
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Icon(
                      LucideIcons.search,
                      color: Colors.grey[500],
                      size: 20,
                    ),
                  ),

                  // Search text field
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      onChanged: (value) {
                        // Debounce search
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (_searchController.text == value) {
                            _performSearch(value);
                          }
                        });
                      },
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search cities, countries...',
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),

                  // Clear button (when text is present)
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: _clearSearch,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          LucideIcons.x,
                          color: Colors.grey[500],
                          size: 18,
                        ),
                      ),
                    ),

                  // Loading indicator
                  if (_isSearching)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),

                  // Filter button with badge
                  GestureDetector(
                    onTap: _toggleFilters,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _filtersExpanded
                                  ? AppColors.oceanBlue.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              LucideIcons.slidersHorizontal,
                              color: _filtersExpanded
                                  ? AppColors.oceanBlue
                                  : Colors.grey[500],
                              size: 18,
                            ),
                          ),
                          // Badge showing active filter count
                          if (activeFilterCount > 0)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.oceanBlue,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  '$activeFilterCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Notification bell with badge
                  _buildNotificationBell(context, isDark),

                  // Divider
                  Container(
                    width: 1,
                    height: 28,
                    color: Colors.grey.withValues(alpha: 0.3),
                  ),

                  // User avatar button
                  GestureDetector(
                    onTap: () => context.push('/profile'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: _buildAvatar(user?.avatarUrl, user?.displayName),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Expandable filter chips panel
        SizeTransition(
          sizeFactor: _filterExpandAnimation,
          axisAlignment: -1,
          child: _buildFilterChips(context, provider, isDark),
        ),

        // Search results dropdown
        if (_searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.grey[900]!.withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: Colors.grey.withValues(alpha: 0.2),
                ),
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  return ListTile(
                    leading: const Icon(
                      LucideIcons.mapPin,
                      color: AppColors.oceanBlue,
                      size: 20,
                    ),
                    title: Text(
                      result.placeName,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: result.context != null
                        ? Text(
                            result.context!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    dense: true,
                    onTap: () => _onResultSelected(result),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAvatar(String? avatarUrl, String? displayName) {
    const double size = 32;

    Widget letterPlaceholder() => Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: AppColors.oceanBlue,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              displayName?.isNotEmpty == true
                  ? displayName![0].toUpperCase()
                  : '?',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );

    if (avatarUrl == null) {
      return letterPlaceholder();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.oceanBlue.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: Image.network(
          avatarUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => letterPlaceholder(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: size,
              height: size,
              color: Colors.grey[300],
              child: const Center(
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotificationBell(BuildContext context, bool isDark) {
    final notificationService = context.read<NotificationService>();

    return StreamBuilder<List<AppNotification>>(
      stream: notificationService.notifications,
      initialData: notificationService.allNotifications,
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? [];
        final unreadCount = notifications.where((n) => !n.read).length;

        return GestureDetector(
          onTap: () => _openNotificationPanel(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    LucideIcons.bell,
                    color: Colors.grey[500],
                    size: 18,
                  ),
                ),
                // Badge showing unread count
                if (unreadCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.punchRed,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openNotificationPanel(BuildContext context) {
    NotificationPanel.show(
      context,
      onNotificationTap: (notification) {
        _navigateToNotificationTarget(context, notification);
      },
    );
  }

  void _navigateToNotificationTarget(
      BuildContext context, AppNotification notification) {
    switch (notification.type) {
      case 'report_recovered':
      case 'report_verified':
        // Navigate to report details if reportId is available
        final reportId = notification.data?['report_id'] as String?;
        if (reportId != null) {
          context.push('/report/$reportId');
        }
        break;
      case 'badge_earned':
        // Navigate to profile to see badges
        context.push('/profile');
        break;
      case 'event_created':
        // Navigate to events list (event detail screen to be added in Phase 2)
        // TODO: Add /events/:eventId route for deep linking to specific event
        context.go('/events');
        break;
      case 'system':
      default:
        // No navigation for system notifications
        break;
    }
  }
}

/// Compact filter chip for the expandable filter panel
class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color selectedColor;
  final bool isDark;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.selectedColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor
              : (isDark ? const Color(0xFF2C2C2E) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? selectedColor
                : (isDark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.08)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
