import '../domain/auth_repository.dart';
import '../domain/entities.dart';
import 'auth_api.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthApi api;

  AuthRepositoryImpl(this.api);

  @override
  Future<void> register(
    String first,
    String last,
    String email,
    String password,
  ) async {
    final res = await api.register({
      "firstName": first,
      "lastName": last,
      "email": email,
      "password": password,
    });

    await api.saveToken(res["token"]);
  }

  @override
  Future<void> login(String email, String password) async {
    final res = await api.login({"email": email, "password": password});

    await api.saveToken(res["token"]);
  }

  @override
  Future<UserEntity> getMe() async {
    final map = await api.getMe();
    return UserEntity.fromJson(map);
  }

  @override
  Future<void> logout() async {
    await api.storage.delete(key: "token");
  }
}
