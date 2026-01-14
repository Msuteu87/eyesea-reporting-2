import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:eyesea_reporting_2/app.dart';
import 'package:eyesea_reporting_2/presentation/providers/auth_provider.dart';
import 'package:eyesea_reporting_2/domain/repositories/auth_repository.dart';
import 'package:eyesea_reporting_2/domain/entities/user.dart';
import 'package:eyesea_reporting_2/core/services/profile_cache_service.dart';
import 'package:eyesea_reporting_2/core/services/connectivity_service.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class MockProfileCacheService extends ProfileCacheService {
  @override
  Future<void> initialize() async {}
  @override
  Future<void> cacheProfile(UserEntity user) async {}
  @override
  Future<UserEntity?> getCachedProfile() async => null;
  @override
  Future<void> clearCache() async {}
}

class MockConnectivityService extends ConnectivityService {
  @override
  bool get isOnline => true;
  @override
  Stream<bool> get onConnectivityChanged => Stream.value(true);
  @override
  Future<void> initialize() async {}
}

class MockAuthRepository implements AuthRepository {
  @override
  Stream<UserEntity?> get onAuthStateChanged => Stream.value(null);
  @override
  UserEntity? get currentUser => null;
  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<UserEntity?> fetchCurrentUser() async => null;
  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signInWithOAuth(OAuthProvider provider) async {}
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
  }) async {}
  @override
  Future<void> uploadAvatar(dynamic imageFile) async {}
}

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    final repo = MockAuthRepository();
    final profileCache = MockProfileCacheService();
    final connectivity = MockConnectivityService();
    final authProvider = AuthProvider(repo, profileCache, connectivity);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Eyesea Reporting')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authProvider),
        ],
        child: EyeseaApp(router: router),
      ),
    );

    // Verify app title or content
    expect(find.text('Eyesea Reporting'), findsOneWidget);
  });
}
