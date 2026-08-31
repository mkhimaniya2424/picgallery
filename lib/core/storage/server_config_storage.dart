import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists a dev-editable override for the backend host (IP or hostname)
/// so switching networks doesn't require hand-editing
/// `api_client.dart`'s `_defaultBaseUrl()` and rebuilding every time.
///
/// Set via the gear icon on [SplashScreen] → [ServerSettingsSheet], which
/// both updates the live [ApiClient.baseUrl] immediately (no restart
/// needed for the current session) and saves it here for next launch.
///
/// flutter_secure_storage ^11 uses EncryptedSharedPreferences on Android
/// by default (the explicit opt-in parameter was removed in v11). This
/// class relies on that default — no per-call AndroidOptions needed.
class ServerConfigStorage {
  static const String _hostKey = 'server_base_host';

  final FlutterSecureStorage _storage;

  ServerConfigStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Just the host/IP, e.g. `172.20.10.4` — port and `/api/v1` are
  /// added back on by whoever builds the full base URL.
  Future<void> saveHost(String host) async {
    await _storage.write(key: _hostKey, value: host);
  }

  Future<String?> readHost() async {
    return _storage.read(key: _hostKey);
  }

  Future<void> clearHost() async {
    await _storage.delete(key: _hostKey);
  }
}