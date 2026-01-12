
import '../../domain/entities/user.dart';

/// Data model for mapping Supabase User to domain entity.
class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
  });

  /// Create from Supabase auth user JSON.
  factory UserModel.fromSupabaseUser(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: (json['email'] as String?) ?? '',
    );
  }

  /// Convert to JSON for API calls.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
    };
  }

  /// Convert to domain entity.
  UserEntity toEntity() {
    return UserEntity(id: id, email: email);
  }
}
