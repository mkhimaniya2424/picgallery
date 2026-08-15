import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/notification_alert.dart';

/// Hive-backed local persistence for the Client "Alerts" tab.
///
/// IMPORTANT:
/// - Stores a single JSON blob for the whole alerts list.
/// - No dummy/seed content.
class AlertsLocalStore {
  static const String _boxName = 'alerts_box';
  static const String _stateKey = 'alerts_state_v1';

  Box<String>? _box;
  bool _initialized = false;

  /// Safe to call multiple times.
  ///
  /// Note: the project already initializes Hive in `main.dart`.
  /// We keep this method consistent with other stores, guarded by
  /// [_initialized] so it won't re-open Hive boxes repeatedly.
  Future<void> init() async {
    if (_initialized) return;
    _box = await Hive.openBox<String>(_boxName);
    _initialized = true;
  }

  Future<List<NotificationAlert>> load() async {
    if (!_initialized) await init();

    final raw = _box?.get(_stateKey);
    if (raw == null || raw.isEmpty) return <NotificationAlert>[];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return <NotificationAlert>[];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(NotificationAlert.fromJson)
        .toList();
  }

  Future<void> saveAll(List<NotificationAlert> alerts) async {
    if (!_initialized) await init();

    final json = alerts.map((e) => e.toJson()).toList();
    await _box?.put(_stateKey, jsonEncode(json));
  }

  Future<void> clear() async {
    if (!_initialized) await init();
    await _box?.delete(_stateKey);
  }
}
