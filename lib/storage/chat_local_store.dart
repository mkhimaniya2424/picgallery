import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/chat_message_model.dart';

class ChatLocalStore {
  static const String _boxName = 'chat_messages_box';
  static const String _stateKey = 'chat_messages_state_v1';

  Box<String>? _box;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _box = await Hive.openBox<String>(_boxName);
    _initialized = true;
  }

  Future<List<ChatMessageModel>> load() async {
    if (!_initialized) await init();
    final raw = _box?.get(_stateKey);
    if (raw == null || raw.isEmpty) return <ChatMessageModel>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <ChatMessageModel>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((json) => ChatMessageModel.fromJson(json))
          .toList();
    } catch (_) {
      return <ChatMessageModel>[];
    }
  }

  Future<void> saveAll(List<ChatMessageModel> messages) async {
    if (!_initialized) await init();
    final jsonList = messages.map((m) => m.toJson()).toList();
    await _box?.put(_stateKey, jsonEncode(jsonList));
  }

  Future<void> clear() async {
    if (!_initialized) await init();
    await _box?.delete(_stateKey);
  }
}
