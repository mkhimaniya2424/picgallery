import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/folder_model.dart';

/// Hive-backed local persistence for folders (including nested
/// sub-folders — each [FolderModel.parentId] is stored as-is, so the
/// whole tree round-trips through a restart exactly as it was).
///
/// Stores a single JSON list under a single Hive key, the same
/// single-key-JSON-blob approach used elsewhere in the app for
/// still-local-only entities.
class FolderLocalStore {
  static const String _boxName = 'folders_box';
  static const String _stateKeyPrefix = 'folders_state_v1';
  static const String _lastUserIdKey = 'folders_state_v1_last_user_id';

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

  Future<List<FolderModel>> load() async {
    if (!_initialized) await init();
    final uid = _userId;
    if (uid == null) return <FolderModel>[];

    final raw = _box?.get(_keyFor(uid));
    if (raw == null || raw.isEmpty) return <FolderModel>[];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return <FolderModel>[];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map((e) => FolderModel.fromJson(e))
        .toList();
  }

  Future<void> saveAll(List<FolderModel> folders) async {
    if (!_initialized) await init();
    final uid = _userId;
    if (uid == null) return;

    final json = folders.map((f) => f.toJson()).toList();
    await _box?.put(_keyFor(uid), jsonEncode(json));
  }

  Future<void> clear() async {
    if (!_initialized) await init();
    final uid = _userId;
    if (uid == null) return;
    await _box?.delete(_keyFor(uid));
  }
}
