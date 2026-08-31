import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin, testable wrapper around [FlutterSecureStorage] for persisting the
/// JWT access token between app launches. Contains no business logic —
/// callers (e.g. [AuthRepository] or an auth provider) decide when to
/// save/read/clear it.
///
/// flutter_secure_storage ^11 uses EncryptedSharedPreferences on Android
/// by default (no opt-in option needed anymore), eliminating the RSA
/// Keystore first-write delay that older versions could trigger.
class TokenStorage {
  static const String _tokenKey = 'auth_access_token';
  static const String _rememberMeKey = 'auth_remember_me';

  final FlutterSecureStorage _storage;

  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> readToken() async {
    return _storage.read(key: _tokenKey);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }

  /// Persists the "Remember me" checkbox choice itself (separate from the
  /// token). This lets the app tell, later, whether the current/last
  /// session was meant to be session-only — e.g. to pre-check/uncheck the
  /// box again, or for any future logic that needs to distinguish "never
  /// opted in to being remembered" from "opted in but the stored token is
  /// simply missing/expired".
  Future<void> saveRememberMe(bool rememberMe) async {
    await _storage.write(
      key: _rememberMeKey,
      value: rememberMe.toString(),
    );
  }

  /// Defaults to `false` (not remembered) if nothing has been saved yet.
  Future<bool> readRememberMe() async {
    final value = await _storage.read(key: _rememberMeKey);
    return value == 'true';
  }

  Future<void> clearRememberMe() async {
    await _storage.delete(key: _rememberMeKey);
  }
}