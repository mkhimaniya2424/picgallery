import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/share_link_model.dart';

/// Hive-backed local persistence for Gallery Share Links.
class ShareLinkLocalStore {
  static const String _boxName = 'share_links_box';
  static const String _stateKey = 'share_links_state_v1';

  Box<String>? _box;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
    _initialized = true;
  }

  Future<List<GalleryShareLink>> load() async {
    if (!_initialized) await init();

    final raw = _box?.get(_stateKey);
    if (raw == null || raw.isEmpty) return <GalleryShareLink>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <GalleryShareLink>[];

      return decoded
          .whereType<Map<String, dynamic>>()
          .map((e) => GalleryShareLink.fromJson(e))
          .toList();
    } catch (_) {
      return <GalleryShareLink>[];
    }
  }

  Future<void> saveAll(List<GalleryShareLink> links) async {
    if (!_initialized) await init();

    final jsonList = links.map((l) => l.toJson()).toList();
    await _box?.put(_stateKey, jsonEncode(jsonList));
  }

  Future<void> clear() async {
    if (!_initialized) await init();
    await _box?.delete(_stateKey);
  }
}
