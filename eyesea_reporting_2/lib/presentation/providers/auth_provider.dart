import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/secure_storage_service.dart';
import '../../core/services/profile_cache_service.dart';
import '../../core/services/connectivity_service.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../core/utils/logger.dart';

/// Provider for authentication state and user profile management.
///
/// ## Offline Mode & Stale Data Indicators
///
/// When the device is offline, cached profile data is used. The UI can check:
/// - [isOfflineMode] - true when using cached data
/// - [lastSyncTime] - when profile was last fetched from server
/// - [timeSinceLastSync] - human-readable duration since last sync
///
/// Example usage in UI:
/// ```dart
/// if (authProvider.isOfflineMode) {
///   Text('Offline • Last synced ${authProvider.timeSinceLastSync}');
/// }
/// ```
///
/// ## Async Initialization
///
/// The [_init] method runs asynchronously without blocking UI. If profile
/// fetch takes longer than expected, the splash screen is shown. For improved
/// UX, consider implementing a loading timeout with retry option.
class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;
  final ProfileCacheService _profileCacheService;
  final ConnectivityService _connectivityService;

  UserEntity? _currentUser;
  bool _isLoading = false;
  bool _isOnboardingComplete = false;
  bool _isInitialized = false;
  bool _isOfflineMode = false;
  DateTime? _lastSyncTime;
  StreamSubscription<UserEntity?>? _authStateSubscription;
  StreamSubscription<bool>? _connectivitySubscription;

  AuthProvider(
    this._authRepository,
    this._profileCacheService,
    this._connectivityService,
  ) {
    _init();
  }

  UserEntity? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get isOnboardingComplete => _isOnboardingComplete;
  bool get isInitialized => _isInitialized;
  bool get isOfflineMode => _isOfflineMode;

  /// When the profile was last successfully fetched from the server.
  /// Null if never synced or not authenticated.
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Human-readable duration since last sync (e.g., "5 min ago", "2 hours ago").
  /// Returns null if never synced.
  String? get timeSinceLastSync {
    if (_lastSyncTime == null) return null;
    final diff = DateTime.now().difference(_lastSyncTime!);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
  }

  /// Public method to trigger router refresh (e.g., after splash completes)
  void refresh() => notifyListeners();

  Future<void> _init() async {
    _currentUser = _authRepository.currentUser;

    // Fetch full profile data immediately if logged in
    if (_currentUser != null) {
      await _fetchOrLoadCachedProfile();
      // One-time migration from SharedPreferences to SecureStorage
      if (_currentUser != null) {
        await _migrateFromSharedPreferences(_currentUser!.id);
      }
    }
    notifyListeners();

    _authStateSubscription = _authRepository.onAuthStateChanged.listen((user) async {
      _currentUser = user;
      if (user != null) {
        // Fetch full profile on auth state change (login)
        await _fetchOrLoadCachedProfile();
      } else {
        // Clear cache on logout
        await _profileCacheService.clearCache();
        _isOfflineMode = false;
      }
      checkOnboardingStatus();
      notifyListeners();
    });

    // Listen for connectivity changes to refresh profile when back online
    _connectivitySubscription = _connectivityService.onConnectivityChanged.listen((isOnline) async {
      if (isOnline && _isOfflineMode && _currentUser != null) {
        AppLogger.info('Back online - refreshing profile');
        await _refreshProfileFromNetwork();
      }
    });

    await checkOnboardingStatus();
    _isInitialized = true;
    notifyListeners();
  }

  /// Fetch profile from network, or fall back to cache if offline
  Future<void> _fetchOrLoadCachedProfile() async {
    try {
      final fullUser = await _authRepository.fetchCurrentUser();
      if (fullUser != null) {
        _currentUser = fullUser;
        _isOfflineMode = false;
        _lastSyncTime = DateTime.now();
        // Cache the profile for offline use
        await _profileCacheService.cacheProfile(fullUser);
        AppLogger.info('Profile fetched and cached');
      }
    } catch (e) {
      AppLogger.warning('Failed to fetch profile from network: $e');
      // Try to load from cache
      await _loadProfileFromCache();
    }
  }

  /// Load profile from local cache (for offline mode)
  Future<void> _loadProfileFromCache() async {
    final basicUser = _authRepository.currentUser;
    if (basicUser == null) return;

    final cachedProfile = await _profileCacheService.getCachedProfile();
    if (cachedProfile != null && cachedProfile.id == basicUser.id) {
      _currentUser = cachedProfile;
      _isOfflineMode = true;
      AppLogger.info('Loaded profile from cache (offline mode)');
    } else {
      // No cache available - use basic user info from Supabase session
      _currentUser = basicUser;
      _isOfflineMode = true;
      AppLogger.info('Using basic profile from session (offline mode, no cache)');
    }
  }

  /// Refresh profile from network when connectivity is restored
  Future<void> _refreshProfileFromNetwork() async {
    try {
      final fullUser = await _authRepository.fetchCurrentUser();
      if (fullUser != null) {
        _currentUser = fullUser;
        _isOfflineMode = false;
        _lastSyncTime = DateTime.now();
        await _profileCacheService.cacheProfile(fullUser);
        notifyListeners();
        AppLogger.info('Profile refreshed after reconnection');
      }
    } catch (e) {
      AppLogger.warning('Failed to refresh profile: $e');
    }
  }

  /// Migrates onboarding status from SharedPreferences to SecureStorage (one-time)
  Future<void> _migrateFromSharedPreferences(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final oldKey = 'onboarding_completed_$userId';
      const oldTermsKey = 'terms_accepted';

      // Migrate onboarding status
      if (prefs.containsKey(oldKey)) {
        final value = prefs.getBool(oldKey) ?? false;
        await SecureStorageService.setOnboardingComplete(userId, value);
        await prefs.remove(oldKey);
        AppLogger.info('Migrated onboarding status to secure storage');
      }

      // Migrate terms acceptance
      if (prefs.containsKey(oldTermsKey)) {
        final value = prefs.getBool(oldTermsKey) ?? false;
        await SecureStorageService.setTermsAccepted(value);
        await prefs.remove(oldTermsKey);
        AppLogger.info('Migrated terms acceptance to secure storage');
      }
    } catch (e) {
      AppLogger.warning('Migration from SharedPreferences failed: $e');
      // Non-fatal - user can re-complete onboarding if needed
    }
  }

  Future<void> checkOnboardingStatus() async {
    final user = _currentUser;
    if (user != null) {
      final localComplete =
          await SecureStorageService.isOnboardingComplete(user.id);

      final hasName = user.displayName != null && user.displayName!.isNotEmpty;

      if (!hasName) {
        // Must complete registration
        _isOnboardingComplete = false;
      } else {
        // Has name, check local device permission flag
        _isOnboardingComplete = localComplete;
      }
    } else {
      _isOnboardingComplete = false;
    }
    notifyListeners();
  }

  Future<void> acceptTerms() async {
    await SecureStorageService.setTermsAccepted(true);
    notifyListeners();
  }

  Future<bool> hasAcceptedTerms() async {
    return SecureStorageService.hasAcceptedTerms();
  }

  Future<void> setOnboardingComplete() async {
    final user = _currentUser;
    if (user != null) {
      await SecureStorageService.setOnboardingComplete(user.id, true);
      _isOnboardingComplete = true;
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authRepository.signIn(email, password);
    } catch (e) {
      AppLogger.error('Login failed: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUp(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authRepository.signUp(email, password);
    } catch (e) {
      AppLogger.error('Sign up failed: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await _authRepository.signOut();
    } catch (e) {
      AppLogger.error('Logout failed: $e');
      rethrow;
    }
  }

  /// Update user's password (called after clicking reset link in email)
  Future<void> updatePassword(String newPassword) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authRepository.updatePassword(newPassword);
      AppLogger.info('Password updated successfully');
    } catch (e) {
      AppLogger.error('Password update failed: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithOAuth(OAuthProvider provider) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authRepository.signInWithOAuth(provider);
    } catch (e) {
      AppLogger.error('SSO Login failed: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    required String displayName,
    required String country,
    UserRole? role,
    String? currentVesselId,
    String? orgId,
    DateTime? gdprConsentAt,
    bool? marketingOptIn,
    DateTime? termsAcceptedAt,
  }) async {
    final user = _currentUser;
    if (user == null) throw Exception('User not logged in');

    _isLoading = true;
    notifyListeners();

    try {
      await _authRepository.updateProfile(
        displayName: displayName,
        country: country,
        role: role,
        currentVesselId: currentVesselId,
        orgId: orgId,
        gdprConsentAt: gdprConsentAt,
        marketingOptIn: marketingOptIn,
        termsAcceptedAt: termsAcceptedAt,
      );

      // Refresh user to get updated data
      final updatedUser = await _authRepository.fetchCurrentUser();
      if (updatedUser != null) {
        _currentUser = updatedUser;
        // Update cache with new profile data
        await _profileCacheService.cacheProfile(updatedUser);
      }
    } catch (e) {
      AppLogger.error('Failed to update profile: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> uploadAvatar(dynamic imageFile) async {
    final user = _currentUser;
    if (user == null) throw Exception('User not logged in');

    _isLoading = true;
    notifyListeners();

    try {
      await _authRepository.uploadAvatar(imageFile);

      // Refresh user to get updated avatar URL
      final updatedUser = await _authRepository.fetchCurrentUser();
      if (updatedUser != null) {
        _currentUser = updatedUser;
        // Update cache with new avatar URL
        await _profileCacheService.cacheProfile(updatedUser);
      }
    } catch (e) {
      AppLogger.error('Failed to upload avatar: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
