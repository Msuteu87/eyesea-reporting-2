
import '../repositories/auth_repository.dart';

class SignInUseCase {
  final AuthRepository _repository;

  SignInUseCase(this._repository);

  Future<void> call(String email, String password) {
    return _repository.signIn(email, password);
  }
}
