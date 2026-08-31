import 'secure_storage.dart';

/// Testable wrapper around [SecureStorage] for persisting JWT
/// access and refresh tokens between app launches.
class TokenStorage {
  final SecureStorage _secureStorage;

  TokenStorage({SecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? SecureStorage();

  Future<void> saveToken(String token) => _secureStorage.saveAccessToken(token);

  Future<String?> readToken() => _secureStorage.getAccessToken();

  Future<void> saveRefreshToken(String token) => _secureStorage.saveRefreshToken(token);

  Future<String?> readRefreshToken() => _secureStorage.getRefreshToken();

  Future<void> saveTokens({required String accessToken, required String refreshToken}) =>
      _secureStorage.saveTokens(accessToken: accessToken, refreshToken: refreshToken);

  Future<void> clearToken() => _secureStorage.clearTokens();

  Future<void> saveRememberMe(bool rememberMe) => _secureStorage.saveRememberMe(rememberMe);

  Future<bool> readRememberMe() => _secureStorage.readRememberMe();

  Future<void> clearRememberMe() => _secureStorage.clearRememberMe();
}