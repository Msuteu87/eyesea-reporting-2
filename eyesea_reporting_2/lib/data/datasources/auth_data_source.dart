import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/exceptions.dart';
import '../../core/services/auth_rate_limiter.dart';
import '../../core/services/image_validation_service.dart';
import '../../core/utils/error_mapper.dart';
import '../../core/utils/logger.dart';

// NOTE: Avatar upload validation (size/MIME type) implemented via ImageValidationService
// NOTE: Auth rate limiting implemented via AuthRateLimiter (exponential backoff)

/// Data source for authentication operations.
class AuthDataSource {
  final SupabaseClient _supabase;
  final AuthRateLimiter _rateLimiter = AuthRateLimiter();

  AuthDataSource(this._supabase);

  /// Check if auth is currently rate limited
  bool get isRateLimited => _rateLimiter.isLockedOut;

  /// Time remaining until rate limit expires
  Duration get rateLimitRemaining => _rateLimiter.lockoutRemaining;

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    // Check rate limit before attempting
    await _rateLimiter.checkAndWait();

    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
      _rateLimiter.recordSuccess();
    } catch (e, stackTrace) {
      _rateLimiter.recordFailure();
      throw ErrorMapper.mapAuthError(e, stackTrace);
    }
  }

  Future<void> signUpWithEmailAndPassword(String email, String password) async {
    try {
      await _supabase.auth.signUp(email: email, password: password);
    } catch (e, stackTrace) {
      throw ErrorMapper.mapAuthError(e, stackTrace);
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      _rateLimiter.reset(); // Clear rate limit state on logout
    } catch (e, stackTrace) {
      throw ErrorMapper.mapAuthError(e, stackTrace);
    }
  }

  User? get currentUser => _supabase.auth.currentUser;

  Stream<AuthState> get onAuthStateChange => _supabase.auth.onAuthStateChange;

  Future<void> signInWithOAuth(OAuthProvider provider) async {
    try {
      await _supabase.auth.signInWithOAuth(
        provider,
        redirectTo: kIsWeb ? null : 'com.mariussuteu.eyesea.eyeseareporting://login-callback',
      );
    } catch (e, stackTrace) {
      throw ErrorMapper.mapAuthError(e, stackTrace);
    }
  }

  Future<Map<String, dynamic>?> fetchUserProfile(String userId) async {
    try {
      // Fetch profile and related organization info
      final response = await _supabase.from('profiles').select('''
            *,
            current_vessel: current_vessel_id (
              id,
              name,
              organization: org_id (
                id,
                name,
                logo_url
              )
            ),
            organization_members (
              role,
              organizations (
                id,
                name,
                logo_url
              )
            )
          ''').eq('id', userId).maybeSingle();
      return response;
    } catch (e, stackTrace) {
      throw ErrorMapper.mapServerError(e, stackTrace);
    }
  }

  Future<void> updateUserProfile(
      String userId, Map<String, dynamic> data) async {
    try {
      await _supabase.from('profiles').update(data).eq('id', userId);
    } catch (e, stackTrace) {
      throw ErrorMapper.mapServerError(e, stackTrace);
    }
  }

  Future<String> uploadAvatar(String userId, File imageFile) async {
    // Validate image before upload (size and MIME type)
    final validation = ImageValidationService.validateAvatarImage(imageFile);
    if (!validation.isValid) {
      throw ValidationException(message: validation.errorMessage!);
    }

    try {
      final fileSize = imageFile.lengthSync();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '$userId/$fileName';

      AppLogger.info('[Avatar] Uploading file: $path (size: $fileSize bytes)');

      await _supabase.storage.from('avatars').upload(
        path,
        imageFile,
        fileOptions: const FileOptions(
          upsert: true,
          contentType: 'image/jpeg',
        ),
      );

      final publicUrl = _supabase.storage.from('avatars').getPublicUrl(path);
      // Add cache-busting query parameter to ensure fresh image loads
      final cacheBustedUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      AppLogger.info('[Avatar] Upload successful. URL: $cacheBustedUrl');
      return cacheBustedUrl;
    } catch (e, stackTrace) {
      throw ErrorMapper.mapServerError(e, stackTrace);
    }
  }

  /// Fetch the organization ID for a given vessel
  Future<String?> getVesselOrgId(String vesselId) async {
    try {
      final response = await _supabase
          .from('vessels')
          .select('org_id')
          .eq('id', vesselId)
          .maybeSingle();
      return response?['org_id'] as String?;
    } catch (e) {
      AppLogger.error('[AuthDataSource] Failed to fetch vessel org_id', e);
      return null;
    }
  }

  /// Upsert a user into organization_members
  Future<void> upsertOrganizationMember(String userId, String orgId,
      {String role = 'member'}) async {
    try {
      await _supabase.from('organization_members').upsert(
        {
          'user_id': userId,
          'org_id': orgId,
          'role': role,
        },
        onConflict: 'user_id,org_id',
      );
    } catch (e) {
      AppLogger.error('[AuthDataSource] Failed to upsert organization member', e);
      // Don't throw - membership is secondary to profile update
    }
  }
}
