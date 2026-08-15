import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/studio_model.dart';

class StudioLocalStore {
  static const String _boxName = 'studios_box';
  static const String _stateKey = 'studios_state_v1';

  Box<String>? _box;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _box = await Hive.openBox<String>(_boxName);
    _initialized = true;
  }

  Future<List<StudioModel>> load() async {
    if (!_initialized) await init();
    final raw = _box?.get(_stateKey);
    if (raw == null || raw.isEmpty) return <StudioModel>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <StudioModel>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((json) => StudioModel.fromJson(json))
          .toList();
    } catch (_) {
      return <StudioModel>[];
    }
  }

  Future<void> saveAll(List<StudioModel> studios) async {
    if (!_initialized) await init();
    final jsonList = studios.map((s) => s.toJson()).toList();
    await _box?.put(_stateKey, jsonEncode(jsonList));
  }

  Future<void> clear() async {
    if (!_initialized) await init();
    await _box?.delete(_stateKey);
  }
}
