import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';

/// Background message handler - must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if needed (for background isolate)
  await Firebase.initializeApp();
  AppLogger.info('Background message: ${message.messageId}');
  // The system will show the notification automatically from the payload
}

/// Service for handling Firebase Cloud Messaging (FCM) push notifications.
///
/// This service manages:
/// - Firebase initialization
/// - FCM token registration and refresh
/// - Foreground/background message handling
/// - Token storage in Supabase for server-side push delivery
///
/// ## Usage
///
/// Initialize in main.dart before runApp:
/// ```dart
/// final pushService = PushNotificationService(supabaseClient);
/// await pushService.initialize();
/// ```
///
/// ## Architecture
///
/// Push notifications flow:
/// 1. App launches → Get FCM token → Store in Supabase `device_tokens` table
/// 2. Server inserts notification → Edge Function → FCM API → Device
/// 3. App receives → Show notification (background: system, foreground: local)
class PushNotificationService {
  final SupabaseClient _supabase;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<AuthState>? _authSubscription;

  String? _currentToken;
  bool _isInitialized = false;

  /// Callback for when a notification is tapped (for navigation)
  void Function(Map<String, dynamic> data)? onNotificationTap;

  /// Callback for foreground messages (to show in-app banner)
  void Function(RemoteMessage message)? onForegroundMessage;

  PushNotificationService(this._supabase);

  /// Whether the service is initialized
  bool get isInitialized => _isInitialized;

  /// Current FCM token (null if not registered)
  String? get currentToken => _currentToken;

  /// Initialize Firebase and FCM
  ///
  /// Call this in main.dart before runApp, after Firebase.initializeApp()
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kIsWeb) {
      AppLogger.info('Push notifications not supported on web');
      return;
    }

    try {
      // Set up background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request permission (iOS requires explicit permission)
      await _requestPermission();

      // Get initial token
      await _getAndStoreToken();

      // Listen for token refresh
      _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((newToken) {
        AppLogger.info('FCM token refreshed');
        _storeToken(newToken);
      });

      // Handle foreground messages
      _foregroundSubscription =
          FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification tap (when app is in background/terminated)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from a notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        AppLogger.info('App opened from notification');
        _handleNotificationTap(initialMessage);
      }

      // Listen for auth changes to register/unregister token
      _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
        if (data.session != null) {
          // User logged in - register token
          _getAndStoreToken();
        } else {
          // User logged out - remove token from server
          _removeToken();
        }
      });

      _isInitialized = true;
      AppLogger.info('Push notification service initialized');
    } catch (e) {
      AppLogger.error('Error initializing push notifications: $e');
    }
  }

  /// Request notification permission
  Future<bool> _requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      AppLogger.info('Push permission: ${settings.authorizationStatus}');
      return granted;
    } catch (e) {
      AppLogger.error('Error requesting push permission: $e');
      return false;
    }
  }

  /// Get FCM token and store it
  Future<void> _getAndStoreToken() async {
    try {
      // Get APNs token first on iOS (required for FCM to work)
      if (Platform.isIOS) {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null) {
          AppLogger.warning('APNs token not available yet, will retry');
          // Retry after a short delay (APNs token may take time on first launch)
          Future.delayed(const Duration(seconds: 2), _getAndStoreToken);
          return;
        }
      }

      final token = await _messaging.getToken();
      if (token != null) {
        _currentToken = token;
        await _storeToken(token);
      } else {
        AppLogger.warning('FCM token is null');
      }
    } catch (e) {
      AppLogger.error('Error getting FCM token: $e');
    }
  }

  /// Store token in Supabase
  Future<void> _storeToken(String token) async {
    _currentToken = token;

    // Only store if user is logged in
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      AppLogger.debug('Not storing token - user not logged in');
      return;
    }

    try {
      final platform = Platform.isIOS ? 'ios' : 'android';

      // Use the upsert function we created in the migration
      await _supabase.rpc('upsert_device_token', params: {
        'p_token': token,
        'p_platform': platform,
      });

      AppLogger.info('FCM token stored in Supabase');
    } catch (e) {
      AppLogger.error('Error storing FCM token: $e');
    }
  }

  /// Remove token from Supabase (on logout)
  Future<void> _removeToken() async {
    if (_currentToken == null) return;

    try {
      await _supabase.rpc('remove_device_token', params: {
        'p_token': _currentToken,
      });
      AppLogger.info('FCM token removed from Supabase');
    } catch (e) {
      AppLogger.error('Error removing FCM token: $e');
    }

    _currentToken = null;
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    AppLogger.info('Foreground message: ${message.notification?.title}');

    // Notify callback (for showing in-app banner)
    onForegroundMessage?.call(message);

    // The existing NotificationService will show an in-app banner via Supabase Realtime
    // FCM foreground messages don't show system notifications by default
    // If needed, we could show a local notification here using flutter_local_notifications
  }

  /// Handle notification tap (app opened from notification)
  void _handleNotificationTap(RemoteMessage message) {
    AppLogger.info('Notification tapped: ${message.data}');

    // Extract data for navigation
    final data = message.data;
    onNotificationTap?.call(data);
  }

  /// Manually trigger token registration (e.g., after user grants permission later)
  Future<void> registerToken() async {
    await _getAndStoreToken();
  }

  /// Check if push notifications are supported and enabled
  Future<bool> isEnabled() async {
    if (kIsWeb) return false;

    try {
      final settings = await _messaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      return false;
    }
  }

  /// Delete the FCM token (for debugging/testing)
  Future<void> deleteToken() async {
    await _removeToken();
    await _messaging.deleteToken();
    AppLogger.info('FCM token deleted');
  }

  /// Dispose resources
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _foregroundSubscription?.cancel();
    _authSubscription?.cancel();
  }
}
