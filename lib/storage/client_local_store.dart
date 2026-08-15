import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/client_model.dart';

class ClientLocalStore {
  static const String _boxName = 'clients_box';
  static const String _stateKey = 'clients_state_v1';

  Box<String>? _box;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _box = await Hive.openBox<String>(_boxName);
    _initialized = true;
  }

  Future<List<ClientModel>> load() async {
    if (!_initialized) await init();
    final raw = _box?.get(_stateKey);
    if (raw == null || raw.isEmpty) return <ClientModel>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <ClientModel>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((json) => ClientModel.fromJson(json))
          .toList();
    } catch (_) {
      return <ClientModel>[];
    }
  }

  Future<void> saveAll(List<ClientModel> clients) async {
    if (!_initialized) await init();
    final jsonList = clients.map((c) => c.toJson()).toList();
    await _box?.put(_stateKey, jsonEncode(jsonList));
  }

  Future<void> clear() async {
    if (!_initialized) await init();
    await _box?.delete(_stateKey);
  }
}
