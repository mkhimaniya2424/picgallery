import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/gallery_collection_model.dart';

/// Hive-backed local persistence for gallery collections.
///
/// Stores a single JSON list under a single Hive key for simplicity and
/// compatibility with the rest of the Phase-4 local-store approach.
class GalleryCollectionsLocalStore {
  static const String _boxName = 'gallery_collections_box';
  static const String _stateKey = 'gallery_collections_state_v1';

  Box<String>? _box;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
    _initialized = true;
  }

  Future<List<GalleryCollectionModel>> load() async {
    if (!_initialized) await init();

    final raw = _box?.get(_stateKey);
    if (raw == null || raw.isEmpty) return <GalleryCollectionModel>[];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return <GalleryCollectionModel>[];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map((e) => GalleryCollectionModel.fromJson(e))
        .toList();
  }

  Future<void> saveAll(List<GalleryCollectionModel> collections) async {
    if (!_initialized) await init();

    final json = collections.map((c) => c.toJson()).toList();
    await _box?.put(_stateKey, jsonEncode(json));
  }

  Future<void> clear() async {
    if (!_initialized) await init();
    await _box?.delete(_stateKey);
  }
}
