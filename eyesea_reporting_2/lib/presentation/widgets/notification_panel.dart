import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_colors.dart';
import 'notification_list_item.dart';

/// Bottom sheet panel displaying all notifications grouped by time.
/// Shows notification history with mark-as-read and navigation functionality.
class NotificationPanel extends StatelessWidget {
  final NotificationService notificationService;
  final void Function(AppNotification notification)? onNotificationTap;

  const NotificationPanel({
    super.key,
    required this.notificationService,
    this.onNotificationTap,
  });

  /// Show the notification panel as a modal bottom sheet
  static Future<void> show(
    BuildContext context, {
    void Function(AppNotification notification)? onNotificationTap,
  }) {
    final notificationService = context.read<NotificationService>();

    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => NotificationPanel(
        notificationService: notificationService,
        onNotificationTap: onNotificationTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              _buildHeader(context, isDark),

              const Divider(height: 1),

              // Notification list
              Expanded(
                child: StreamBuilder<List<AppNotification>>(
                  stream: notificationService.notifications,
                  initialData: notificationService.allNotifications,
                  builder: (context, snapshot) {
                    final notifications = snapshot.data ?? [];

                    if (notifications.isEmpty) {
                      return _buildEmptyState(isDark);
                    }

                    return _buildGroupedList(
                      context,
                      notifications,
                      scrollController,
                      isDark,
                      bottomPadding,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Text(
            'Notifications',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => notificationService.markAllAsRead(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.electricNavy,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.checkCheck, size: 16),
                SizedBox(width: 6),
                Text(
                  'Mark all read',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.bellOff,
                size: 36,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "You'll see updates about your\nreports and achievements here",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedList(
    BuildContext context,
    List<AppNotification> notifications,
    ScrollController scrollController,
    bool isDark,
    double bottomPadding,
  ) {
    final grouped = _groupNotificationsByTime(notifications);

    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.only(bottom: bottomPadding + 20),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final group = grouped[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text(
                group.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                  letterSpacing: 0.5,
                ),
              ),
            ),
            // Notification items
            ...group.notifications.map(
              (notification) => NotificationListItem(
                notification: notification,
                onTap: () => _handleNotificationTap(context, notification),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleNotificationTap(
      BuildContext context, AppNotification notification) {
    // Mark as read
    notificationService.markAsRead(notification.id);

    // Notify parent for navigation
    if (onNotificationTap != null) {
      Navigator.pop(context);
      onNotificationTap!(notification);
    }
  }

  /// Group notifications by time period
  List<_NotificationGroup> _groupNotificationsByTime(
      List<AppNotification> notifications) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisWeek = today.subtract(const Duration(days: 7));

    final todayList = <AppNotification>[];
    final yesterdayList = <AppNotification>[];
    final thisWeekList = <AppNotification>[];
    final olderList = <AppNotification>[];

    for (final notification in notifications) {
      final notificationDate = DateTime(
        notification.createdAt.year,
        notification.createdAt.month,
        notification.createdAt.day,
      );

      if (notificationDate.isAtSameMomentAs(today) ||
          notificationDate.isAfter(today)) {
        todayList.add(notification);
      } else if (notificationDate.isAtSameMomentAs(yesterday) ||
          notificationDate.isAfter(yesterday)) {
        yesterdayList.add(notification);
      } else if (notificationDate.isAfter(thisWeek)) {
        thisWeekList.add(notification);
      } else {
        olderList.add(notification);
      }
    }

    final groups = <_NotificationGroup>[];

    if (todayList.isNotEmpty) {
      groups.add(_NotificationGroup(title: 'TODAY', notifications: todayList));
    }
    if (yesterdayList.isNotEmpty) {
      groups.add(
          _NotificationGroup(title: 'YESTERDAY', notifications: yesterdayList));
    }
    if (thisWeekList.isNotEmpty) {
      groups.add(
          _NotificationGroup(title: 'THIS WEEK', notifications: thisWeekList));
    }
    if (olderList.isNotEmpty) {
      groups.add(_NotificationGroup(title: 'OLDER', notifications: olderList));
    }

    return groups;
  }
}

/// Helper class for grouped notifications
class _NotificationGroup {
  final String title;
  final List<AppNotification> notifications;

  _NotificationGroup({required this.title, required this.notifications});
}
