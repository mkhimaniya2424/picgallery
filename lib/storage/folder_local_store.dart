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
  static const String _stateKey = 'folders_state_v1';

  Box<String>? _box;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
    _initialized = true;
  }

  Future<List<FolderModel>> load() async {
    if (!_initialized) await init();

    final raw = _box?.get(_stateKey);
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

    final json = folders.map((f) => f.toJson()).toList();
    await _box?.put(_stateKey, jsonEncode(json));
  }

  Future<void> clear() async {
    if (!_initialized) await init();
    await _box?.delete(_stateKey);
  }
}
