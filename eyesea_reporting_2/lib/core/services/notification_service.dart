import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Notification model matching the database schema
class AppNotification {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String? body;
  final Map<String, dynamic>? data;
  final bool read;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    this.body,
    this.data,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String?,
      data: json['data'] as Map<String, dynamic>?,
      read: json['read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Service for handling notifications via Supabase Realtime and local notifications.
/// Shows native device notifications when new notifications arrive.
class NotificationService {
  final SupabaseClient _supabase;
  RealtimeChannel? _channel;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final _notificationsController =
      StreamController<List<AppNotification>>.broadcast();
  final _newNotificationController =
      StreamController<AppNotification>.broadcast();

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _localNotificationsInitialized = false;
  bool _hasNotificationPermission = false;

  /// Stream of all notifications (updated when new ones arrive)
  Stream<List<AppNotification>> get notifications =>
      _notificationsController.stream;

  /// Stream of individual new notifications (for showing toasts/banners)
  Stream<AppNotification> get onNewNotification =>
      _newNotificationController.stream;

  /// Current unread count
  int get unreadCount => _unreadCount;

  /// All cached notifications
  List<AppNotification> get allNotifications =>
      List.unmodifiable(_notifications);

  /// Whether notification permission has been granted
  bool get hasPermission => _hasNotificationPermission;

  NotificationService(this._supabase);

  /// Initialize the service and start listening for notifications
  Future<void> initialize() async {
    // Initialize local notifications first
    await _initializeLocalNotifications();

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('🔔 NotificationService: No user logged in, skipping init');
      return;
    }

    // Load existing notifications
    await _loadNotifications();

    // Subscribe to realtime changes
    _subscribeToRealtime(userId);
  }

  /// Initialize flutter_local_notifications
  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // We'll request separately during onboarding
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _localNotificationsInitialized = true;
    debugPrint('🔔 Local notifications initialized');
  }

  /// Request notification permission (call from onboarding)
  Future<bool> requestPermission() async {
    if (kIsWeb) {
      _hasNotificationPermission = false;
      return false;
    }

    try {
      if (Platform.isIOS) {
        final result = await _localNotifications
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
        _hasNotificationPermission = result ?? false;
      } else if (Platform.isAndroid) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        // Android 13+ requires explicit permission
        final result = await androidPlugin?.requestNotificationsPermission();
        _hasNotificationPermission = result ?? true; // Android < 13 doesn't need permission
      }

      debugPrint(
          '🔔 Notification permission: $_hasNotificationPermission');
      return _hasNotificationPermission;
    } catch (e) {
      debugPrint('🔔 Error requesting notification permission: $e');
      _hasNotificationPermission = false;
      return false;
    }
  }

  /// Check if notification permission is granted
  Future<bool> checkPermission() async {
    if (kIsWeb) return false;

    try {
      if (Platform.isIOS) {
        final result = await _localNotifications
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.checkPermissions();
        _hasNotificationPermission = result?.isEnabled ?? false;
      } else if (Platform.isAndroid) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final result = await androidPlugin?.areNotificationsEnabled();
        _hasNotificationPermission = result ?? false;
      }
      return _hasNotificationPermission;
    } catch (e) {
      debugPrint('🔔 Error checking notification permission: $e');
      return false;
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    // Could navigate to specific screen based on payload
  }

  /// Show a local notification
  Future<void> _showLocalNotification(AppNotification notification) async {
    if (!_hasNotificationPermission) {
      // Check permission status
      await checkPermission();
      if (!_hasNotificationPermission) {
        debugPrint('🔔 Skipping local notification - no permission');
        return;
      }
    }

    const androidDetails = AndroidNotificationDetails(
      'eyesea_notifications',
      'Eyesea Notifications',
      channelDescription: 'Notifications about your pollution reports',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Use hashCode of id for notification id (needs to be int)
    final notificationId = notification.id.hashCode;

    await _localNotifications.show(
      notificationId,
      notification.title,
      notification.body,
      details,
      payload: notification.id,
    );

    debugPrint('🔔 Local notification shown: ${notification.title}');
  }

  /// Load existing notifications from database
  Future<void> _loadNotifications() async {
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(50);

      _notifications = (response as List)
          .map((json) => AppNotification.fromJson(json))
          .toList();

      _unreadCount = _notifications.where((n) => !n.read).length;
      _notificationsController.add(_notifications);

      debugPrint(
          '🔔 Loaded ${_notifications.length} notifications ($unreadCount unread)');
    } catch (e) {
      debugPrint('🔔 Error loading notifications: $e');
    }
  }

  /// Subscribe to realtime notifications for the current user
  void _subscribeToRealtime(String userId) {
    _channel = _supabase
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            debugPrint('🔔 New notification received: ${payload.newRecord}');
            _handleNewNotification(payload.newRecord);
          },
        )
        .subscribe();

    debugPrint('🔔 Subscribed to realtime notifications');
  }

  /// Handle a new notification from realtime
  void _handleNewNotification(Map<String, dynamic> json) {
    try {
      final notification = AppNotification.fromJson(json);

      // Add to the beginning of the list
      _notifications.insert(0, notification);
      _unreadCount++;

      // Emit to streams (for in-app UI)
      _notificationsController.add(_notifications);
      _newNotificationController.add(notification);

      // Show native local notification
      _showLocalNotification(notification);

      debugPrint('🔔 Notification added: ${notification.title}');
    } catch (e) {
      debugPrint('🔔 Error parsing notification: $e');
    }
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'read': true}).eq('id', notificationId);

      // Update local state
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1 && !_notifications[index].read) {
        _notifications[index] = AppNotification(
          id: _notifications[index].id,
          userId: _notifications[index].userId,
          type: _notifications[index].type,
          title: _notifications[index].title,
          body: _notifications[index].body,
          data: _notifications[index].data,
          read: true,
          createdAt: _notifications[index].createdAt,
        );
        _unreadCount--;
        _notificationsController.add(_notifications);
      }
    } catch (e) {
      debugPrint('🔔 Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('notifications')
          .update({'read': true})
          .eq('user_id', userId)
          .eq('read', false);

      // Update local state
      _notifications = _notifications.map((n) {
        if (!n.read) {
          return AppNotification(
            id: n.id,
            userId: n.userId,
            type: n.type,
            title: n.title,
            body: n.body,
            data: n.data,
            read: true,
            createdAt: n.createdAt,
          );
        }
        return n;
      }).toList();

      _unreadCount = 0;
      _notificationsController.add(_notifications);
    } catch (e) {
      debugPrint('🔔 Error marking all as read: $e');
    }
  }

  /// Refresh notifications from database
  Future<void> refresh() async {
    await _loadNotifications();
  }

  /// Dispose resources
  void dispose() {
    _channel?.unsubscribe();
    _notificationsController.close();
    _newNotificationController.close();
  }
}
