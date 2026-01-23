import '../entities/user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Abstract repository for authentication-related operations.
abstract class AuthRepository {
  /// Stream of user authentication state changes.
  Stream<UserEntity?> get onAuthStateChanged;

  /// Returns the current authenticated user, if any.
  UserEntity? get currentUser;

  /// Signs in a user with email and password.
  Future<void> signIn(String email, String password);

  /// Signs up a new user with email and password.
  Future<void> signUp(String email, String password);

  /// Signs in a user using an OAuth provider (e.g., Google, Apple).
  Future<void> signInWithOAuth(OAuthProvider provider);

  /// Signs out the current user.
  Future<void> signOut();

  /// Updates the user's profile information.
  Future<void> updateProfile({
    required String displayName,
    required String country,
    UserRole? role,
    String? currentVesselId,
    String? orgId,
    DateTime? gdprConsentAt,
    bool? marketingOptIn,
    DateTime? termsAcceptedAt,
  });

  /// Uploads a new avatar image for the user.
  ///
  /// [imageFile] expects a `File` object on mobile/desktop.
  Future<void> uploadAvatar(dynamic imageFile);

  /// Fetches the latest user profile data from the remote source.
  Future<UserEntity?> fetchCurrentUser();

  /// Sends a password reset email to the specified email address.
  Future<void> resetPasswordForEmail(String email);

  /// Updates the user's password (called after clicking reset link).
  Future<void> updatePassword(String newPassword);
}
