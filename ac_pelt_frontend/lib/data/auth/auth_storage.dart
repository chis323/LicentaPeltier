import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'jwt_token';

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<void> saveToken(String token) => _storage.write(
        key: _tokenKey,
        value: token,
      );

  Future<void> clearToken() => _storage.delete(key: _tokenKey);
}
