import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/secure_storage_service.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../core/utils/logger.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;
  UserEntity? _currentUser;
  bool _isLoading = false;
  bool _isOnboardingComplete = false;
  bool _isInitialized = false;
  StreamSubscription<UserEntity?>? _authStateSubscription;

  AuthProvider(this._authRepository) {
    _init();
  }

  UserEntity? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get isOnboardingComplete => _isOnboardingComplete;
  bool get isInitialized => _isInitialized;

  /// Public method to trigger router refresh (e.g., after splash completes)
  void refresh() => notifyListeners();

  Future<void> _init() async {
    _currentUser = _authRepository.currentUser;

    // Fetch full profile data immediately if logged in
    if (_currentUser != null) {
      final fullUser = await _authRepository.fetchCurrentUser();
      if (fullUser != null) {
        _currentUser = fullUser;
      }
      // One-time migration from SharedPreferences to SecureStorage
      await _migrateFromSharedPreferences(_currentUser!.id);
    }
    notifyListeners();

    _authStateSubscription = _authRepository.onAuthStateChanged.listen((user) {
      _currentUser = user;
      checkOnboardingStatus(); // Re-evaluate when user data changes (e.g. login/signup)
      notifyListeners();
    });

    await checkOnboardingStatus();
    _isInitialized = true;
    notifyListeners();
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
    super.dispose();
  }
}
