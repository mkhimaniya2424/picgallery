import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class SettingsLocalStore {
  static const String _boxName = 'settings_box';
  static const String _stateKey = 'settings_state_v1';

  Box<String>? _box;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _box = await Hive.openBox<String>(_boxName);
    _initialized = true;
  }

  Future<Map<String, dynamic>?> load() async {
    if (!_initialized) await init();
    final raw = _box?.get(_stateKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(Map<String, dynamic> state) async {
    if (!_initialized) await init();
    await _box?.put(_stateKey, jsonEncode(state));
  }

  Future<void> clear() async {
    if (!_initialized) await init();
    await _box?.delete(_stateKey);
  }
}
