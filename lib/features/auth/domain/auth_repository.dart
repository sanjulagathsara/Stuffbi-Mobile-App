import 'entities.dart';

abstract class AuthRepository {
  Future<void> register(
    String first,
    String last,
    String email,
    String password,
  );
  Future<void> login(String email, String password);
  Future<UserEntity> getMe();
  Future<void> logout();
}
