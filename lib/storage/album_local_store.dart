import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/album_model.dart';

/// Hive-backed local persistence for albums.
///
/// Stores a single JSON list under a single Hive key.
class AlbumLocalStore {
  static const String _boxName = 'albums_box';
  static const String _stateKey = 'albums_state_v1';

  Box<String>? _box;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
    _initialized = true;
  }

  Future<List<AlbumModel>> load() async {
    if (!_initialized) await init();

    final raw = _box?.get(_stateKey);
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

    final json = albums.map((a) => a.toJson()).toList();
    await _box?.put(_stateKey, jsonEncode(json));
  }

  Future<void> clear() async {
    if (!_initialized) await init();
    await _box?.delete(_stateKey);
  }
}
