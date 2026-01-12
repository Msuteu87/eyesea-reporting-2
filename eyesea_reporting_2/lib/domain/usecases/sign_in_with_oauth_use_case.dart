import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/auth_repository.dart';

class SignInWithOAuthUseCase {
  final AuthRepository _repository;

  SignInWithOAuthUseCase(this._repository);

  Future<void> execute(OAuthProvider provider) {
    return _repository.signInWithOAuth(provider);
  }
}
