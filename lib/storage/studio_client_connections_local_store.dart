import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/studio_client_connection_model.dart';

class StudioClientConnectionsLocalStore {
  static const String _boxName = 'studio_client_connections_box';
  static const String _stateKey = 'connections_state_v1';

  Box<String>? _box;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _box = await Hive.openBox<String>(_boxName);
    _initialized = true;
  }

  Future<List<StudioClientConnection>> load() async {
    if (!_initialized) await init();
    final raw = _box?.get(_stateKey);
    if (raw == null || raw.isEmpty) return <StudioClientConnection>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <StudioClientConnection>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((json) => StudioClientConnection.fromJson(json))
          .toList();
    } catch (_) {
      return <StudioClientConnection>[];
    }
  }

  Future<void> saveAll(List<StudioClientConnection> connections) async {
    if (!_initialized) await init();
    final jsonList = connections.map((c) => c.toJson()).toList();
    await _box?.put(_stateKey, jsonEncode(jsonList));
  }

  Future<void> clear() async {
    if (!_initialized) await init();
    await _box?.delete(_stateKey);
  }
}
