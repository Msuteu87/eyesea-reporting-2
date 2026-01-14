import 'dart:io';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../core/utils/logger.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthDataSource _dataSource;

  AuthRepositoryImpl(this._dataSource);

  @override
  UserEntity? get currentUser {
    final user = _dataSource.currentUser;
    return user != null ? _mapToEntity(user) : null;
  }

  @override
  Future<UserEntity?> fetchCurrentUser() async {
    final user = _dataSource.currentUser;
    if (user == null) return null;
    final profile = await _dataSource.fetchUserProfile(user.id);
    AppLogger.debug('[Avatar] Fetched profile avatar_url: ${profile?['avatar_url']}');
    return _mapToEntity(user, profile);
  }

  @override
  Stream<UserEntity?> get onAuthStateChanged {
    return _dataSource.onAuthStateChange.asyncMap((state) async {
      final user = state.session?.user;
      if (user == null) return null;
      final profile = await _dataSource.fetchUserProfile(user.id);
      return _mapToEntity(user, profile);
    });
  }

  @override
  Future<void> signIn(String email, String password) =>
      _dataSource.signInWithEmailAndPassword(email, password);

  @override
  Future<void> signUp(String email, String password) =>
      _dataSource.signUpWithEmailAndPassword(email, password);

  @override
  Future<void> signInWithOAuth(supabase.OAuthProvider provider) =>
      _dataSource.signInWithOAuth(provider);

  @override
  Future<void> signOut() => _dataSource.signOut();

  @override
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
    final user = _dataSource.currentUser;
    if (user == null) throw Exception('No user logged in');

    final updates = <String, dynamic>{
      'display_name': displayName,
      'country': country,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (role != null) {
      updates['role'] = role.toString().split('.').last;
    }

    if (currentVesselId != null) {
      updates['current_vessel_id'] = currentVesselId;
    }

    // Consent fields
    if (gdprConsentAt != null) {
      updates['gdpr_consent_at'] = gdprConsentAt.toIso8601String();
    }

    if (marketingOptIn != null) {
      updates['marketing_opt_in'] = marketingOptIn;
    }

    if (termsAcceptedAt != null) {
      updates['terms_accepted_at'] = termsAcceptedAt.toIso8601String();
    }

    // Update public profile first
    await _dataSource.updateUserProfile(user.id, updates);

    // If a vessel is selected, also add user to organization_members
    // This ensures Seafarers are properly linked to their organization
    if (currentVesselId != null && currentVesselId.isNotEmpty) {
      // Fetch the org_id from the selected vessel
      final orgIdFromVessel = await _dataSource.getVesselOrgId(currentVesselId);

      if (orgIdFromVessel != null) {
        // Upsert into organization_members (insert or update if exists)
        await _dataSource.upsertOrganizationMember(user.id, orgIdFromVessel);
      }
    }

    // Update auth metadata (optional but keeps things in sync)
    try {
      // We need to access supabase client for this or add method to datasource.
      // DataSource already has client.
      // Let's add updateAuthMetadata to DataSource or just assume Profile is Single Source of Truth.
      // For now, let's keep it simple and skip auth metadata update OR strictly add it to DataSource.
      // Adding it to DataSource is cleaner.
    } catch (_) {}
  }

  @override
  Future<void> uploadAvatar(dynamic imageFile) async {
    final user = _dataSource.currentUser;
    if (user == null) throw Exception('No user logged in');

    if (imageFile is! File) {
      throw Exception('Only File objects are supported for now');
    }

    // 1. Upload Image
    final publicUrl = await _dataSource.uploadAvatar(user.id, imageFile);
    AppLogger.debug('[Avatar] Got public URL: $publicUrl');

    // 2. Update Profile with new URL
    AppLogger.debug('[Avatar] Updating profile with avatar_url...');
    await _dataSource.updateUserProfile(user.id, {
      'avatar_url': publicUrl,
      'updated_at': DateTime.now().toIso8601String(),
    });
    AppLogger.debug('[Avatar] Profile updated successfully');
  }

  UserEntity _mapToEntity(supabase.User user, [Map<String, dynamic>? profile]) {
    // Extract organization info from members OR current vessel
    String? orgName;
    String? orgId;
    String? orgLogoUrl;

    // Check direct membership first
    if (profile != null && profile['organization_members'] != null) {
      final members = profile['organization_members'] as List;
      if (members.isNotEmpty) {
        final orgData = members.first['organizations'];
        if (orgData != null) {
          orgName = orgData['name'];
          orgId = orgData['id'];
          orgLogoUrl = orgData['logo_url'];
        }
      }
    }

    // If no direct membership, check via Vessel
    if (orgId == null && profile != null && profile['current_vessel'] != null) {
      final vesselData = profile['current_vessel'];
      if (vesselData['organization'] != null) {
        final orgData = vesselData['organization'];
        orgName = orgData['name'];
        orgId = orgData['id'];
        orgLogoUrl = orgData['logo_url'];
      }
    }

    // Extract Vessel ID and Name
    String? currentVesselId;
    String? currentVesselName;
    if (profile != null && profile['current_vessel'] != null) {
      final v = profile['current_vessel'];
      // If the join returns the vessel object (which it usually does if fetchUserProfile asks for it)
      // Check for mismatch: profile['current_vessel_id'] is the FK, profile['current_vessel'] is the object
      currentVesselId = profile['current_vessel_id'];
      currentVesselName = v['name'];
    } else if (profile != null && profile['current_vessel_id'] != null) {
      // Fallback if join failed but ID exists
      currentVesselId = profile['current_vessel_id'];
    }

    // Parse Role
    final roleStr = profile?['role'] as String?;
    final role = UserEntity.parseRole(roleStr);

    return UserEntity(
      id: user.id,
      email: user.email ?? '',
      displayName: profile?['display_name'],
      avatarUrl: profile?['avatar_url'],
      country: profile?['country'],
      city: profile?['city'],
      role: role,
      reportsCount: profile?['reports_count'] ?? 0,
      streakDays: profile?['streak_days'] ?? 0,
      orgName: orgName,
      orgId: orgId,
      orgLogoUrl: orgLogoUrl,
      currentVesselId: currentVesselId,
      currentVesselName: currentVesselName,
      ambassadorRegionCountry: profile?['ambassador_region_country'],
      ambassadorRegionName: profile?['ambassador_region_name'],
    );
  }
}
