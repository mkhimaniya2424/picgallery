import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists a dev-editable override for the backend host (IP or hostname)
/// so switching networks doesn't require hand-editing
/// `api_client.dart`'s `_defaultBaseUrl()` and rebuilding every time.
///
/// Set via the gear icon on [SplashScreen] → [ServerSettingsSheet], which
/// both updates the live [ApiClient.baseUrl] immediately (no restart
/// needed for the current session) and saves it here for next launch.
///
/// Uses `encryptedSharedPreferences: true` on Android — same as
/// [TokenStorage] and for the same reason: without it, this plugin falls
/// back to the legacy Keystore-encrypted-shared-prefs backend, which on
/// many devices can silently fail to decrypt on a later read (e.g. after
/// Android's auto backup/restore, a lock-screen/biometric change, or
/// certain OEM Keystore implementations) — the write looks like it
/// succeeded, but [readHost] then comes back `null` forever after,
/// which looked like "the saved server IP isn't remembered — have to
/// re-enter it every launch."
class ServerConfigStorage {
  static const String _hostKey = 'server_base_host';

  static const AndroidOptions _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  final FlutterSecureStorage _storage;

  ServerConfigStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(aOptions: _androidOptions);

  /// Just the host/IP, e.g. `172.20.10.4` — port and `/api/v1` are
  /// added back on by whoever builds the full base URL.
  Future<void> saveHost(String host) async {
    await _storage.write(key: _hostKey, value: host, aOptions: _androidOptions);
  }

  Future<String?> readHost() async {
    return _storage.read(key: _hostKey, aOptions: _androidOptions);
  }

  Future<void> clearHost() async {
    await _storage.delete(key: _hostKey, aOptions: _androidOptions);
  }
}