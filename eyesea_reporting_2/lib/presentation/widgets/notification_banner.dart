import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_colors.dart';

/// A banner that slides down from the top when a new notification arrives.
/// Auto-dismisses after a few seconds or can be tapped to dismiss.
class NotificationBanner extends StatefulWidget {
  final AppNotification notification;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;

  const NotificationBanner({
    super.key,
    required this.notification,
    this.onTap,
    required this.onDismiss,
  });

  @override
  State<NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<NotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // Slide in
    _controller.forward();

    // Auto-dismiss after 4 seconds
    _autoDismissTimer = Timer(const Duration(seconds: 4), _dismiss);
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() async {
    _autoDismissTimer?.cancel();
    await _controller.reverse();
    widget.onDismiss();
  }

  IconData _getIcon() {
    switch (widget.notification.type) {
      case 'report_recovered':
        return LucideIcons.checkCircle2;
      case 'report_verified':
        return LucideIcons.shieldCheck;
      case 'badge_earned':
        return LucideIcons.award;
      default:
        return LucideIcons.bell;
    }
  }

  Color _getIconColor() {
    switch (widget.notification.type) {
      case 'report_recovered':
        return AppColors.successGreen;
      case 'report_verified':
        return AppColors.oceanBlue;
      case 'badge_earned':
        return AppColors.amberGlow;
      default:
        return AppColors.oceanBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    return SlideTransition(
      position: _slideAnimation,
      child: GestureDetector(
        onTap: () {
          widget.onTap?.call();
          _dismiss();
        },
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
            _dismiss();
          }
        },
        child: Container(
          margin: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getIconColor().withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIcon(),
                  size: 20,
                  color: _getIconColor(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.notification.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (widget.notification.body != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.notification.body!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                LucideIcons.x,
                size: 18,
                color: isDark ? Colors.grey[500] : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Overlay widget that listens for notifications and shows banners.
/// Wrap your app's main content with this widget.
class NotificationOverlay extends StatefulWidget {
  final Widget child;
  final NotificationService notificationService;

  const NotificationOverlay({
    super.key,
    required this.child,
    required this.notificationService,
  });

  @override
  State<NotificationOverlay> createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<NotificationOverlay> {
  final List<AppNotification> _activeNotifications = [];
  StreamSubscription<AppNotification>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.notificationService.onNewNotification.listen((notification) {
      if (mounted) {
        setState(() {
          _activeNotifications.add(notification);
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _removeNotification(AppNotification notification) {
    if (mounted) {
      setState(() {
        _activeNotifications.remove(notification);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Show notification banners stacked from top
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Column(
            children: _activeNotifications.map((notification) {
              return NotificationBanner(
                key: ValueKey(notification.id),
                notification: notification,
                onDismiss: () => _removeNotification(notification),
                onTap: () {
                  // Mark as read when tapped
                  widget.notificationService.markAsRead(notification.id);
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
