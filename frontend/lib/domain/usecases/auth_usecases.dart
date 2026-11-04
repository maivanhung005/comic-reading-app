import '../entities/user_entity.dart';
import '../repositories/comic_repository.dart';

class LoginUseCase {
  final ComicRepository repository;
  LoginUseCase(this.repository);
  Future<UserEntity> call(String identifier, String password) => repository.login(identifier, password);
}

class RegisterUseCase {
  final ComicRepository repository;
  RegisterUseCase(this.repository);

  Future<void> call({
    required String name,
    required String username,
    required String email,
    required String password,
    required String birthDate,
    required String gender,
  }) => repository.register(
    name: name,
    username: username,
    email: email,
    password: password,
    birthDate: birthDate,
    gender: gender,
  );
}

class VerifyEmailUseCase {
  final ComicRepository repository;
  VerifyEmailUseCase(this.repository);
  Future<void> call(String email, String code) => repository.verifyEmail(email, code);
}


class BecomeAuthorUseCase {
  final ComicRepository repository;
  BecomeAuthorUseCase(this.repository);
  Future<UserEntity> call({required String penName, required String experience, required bool termsAccepted}) =>
      repository.becomeAuthor(penName: penName, experience: experience, termsAccepted: termsAccepted);
}

class RefreshCurrentUserUseCase {
  final ComicRepository repository;
  RefreshCurrentUserUseCase(this.repository);
  Future<UserEntity> call() => repository.refreshCurrentUser();
}
