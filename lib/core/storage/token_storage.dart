import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin, testable wrapper around [FlutterSecureStorage] for persisting the
/// JWT access token between app launches. Contains no business logic —
/// callers (e.g. [AuthRepository] or an auth provider) decide when to
/// save/read/clear it.
///
/// Uses `encryptedSharedPreferences: true` on Android — without it, the
/// plugin's first-ever write generates an RSA key pair directly in the
/// hardware Keystore, which on many devices is slow enough to freeze the
/// UI thread for 10-30+ seconds (a known flutter_secure_storage issue,
/// showing up as an Android "app isn't responding" dialog right after
/// login). EncryptedSharedPreferences uses AES via Jetpack Security
/// instead, which doesn't have this hang.
class TokenStorage {
  static const String _tokenKey = 'auth_access_token';
  static const String _rememberMeKey = 'auth_remember_me';

  static const AndroidOptions _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  final FlutterSecureStorage _storage;

  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(aOptions: _androidOptions);

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token, aOptions: _androidOptions);
  }

  Future<String?> readToken() async {
    return _storage.read(key: _tokenKey, aOptions: _androidOptions);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey, aOptions: _androidOptions);
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
      aOptions: _androidOptions,
    );
  }

  /// Defaults to `false` (not remembered) if nothing has been saved yet.
  Future<bool> readRememberMe() async {
    final value = await _storage.read(key: _rememberMeKey, aOptions: _androidOptions);
    return value == 'true';
  }

  Future<void> clearRememberMe() async {
    await _storage.delete(key: _rememberMeKey, aOptions: _androidOptions);
  }
}