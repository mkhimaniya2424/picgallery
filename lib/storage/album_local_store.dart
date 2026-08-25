import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/album_model.dart';

/// Hive-backed local persistence for albums.
///
/// Stores a single JSON list under a single Hive key.
class AlbumLocalStore {
  static const String _boxName = 'albums_box';
  static const String _stateKeyPrefix = 'albums_state_v1';
  static const String _lastUserIdKey = 'albums_state_v1_last_user_id';

  Box<String>? _box;
  bool _initialized = false;
  String? _userId;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
    _initialized = true;
  }

  String _keyFor(String userId) => '$_stateKeyPrefix:$userId';

  Future<void> scopeToUser(String userId) async {
    if (!_initialized) await init();

    final lastUserId = _box?.get(_lastUserIdKey);
    if (lastUserId != null && lastUserId != userId) {
      await _box?.delete(_keyFor(lastUserId));
    }
    await _box?.delete(_stateKeyPrefix);

    _userId = userId;
    await _box?.put(_lastUserIdKey, userId);
  }

  Future<void> clearForLogout() async {
    if (!_initialized) await init();

    final uid = _userId ?? _box?.get(_lastUserIdKey);
    if (uid != null) {
      await _box?.delete(_keyFor(uid));
    }
    await _box?.delete(_lastUserIdKey);
    _userId = null;
  }

  Future<List<AlbumModel>> load() async {
    if (!_initialized) await init();
    final uid = _userId;
    if (uid == null) return <AlbumModel>[];

    final raw = _box?.get(_keyFor(uid));
    if (raw == null || raw.isEmpty) return <AlbumModel>[];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return <AlbumModel>[];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map((e) => AlbumModel.fromJson(e))
        .toList();
  }

  Future<void> saveAll(List<AlbumModel> albums) async {
    if (!_initialized) await init();
    final uid = _userId;
    if (uid == null) return;

    final json = albums.map((a) => a.toJson()).toList();
    await _box?.put(_keyFor(uid), jsonEncode(json));
  }

  Future<void> clear() async {
    if (!_initialized) await init();
    final uid = _userId;
    if (uid == null) return;
    await _box?.delete(_keyFor(uid));
  }
}
