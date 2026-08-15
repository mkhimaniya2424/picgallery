import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// Thin on-device persistence layer for the Admin Dashboard.
///
/// Deliberately dumb: it knows nothing about [BookingData] / [ClientData]
/// / etc. It just stores and retrieves one JSON blob (the whole
/// dashboard state) in a Hive box, so the repository is the only place
/// that understands the shape of the data. Swapping this for a real
/// backend later means deleting this file and the two calls to it in
/// [InMemoryAdminDashboardRepository] — nothing else changes.
class DashboardLocalStore {
  static const String _boxName = 'admin_dashboard_box';
  static const String _stateKey = 'dashboard_state_v1';

  Box<String>? _box;
  bool _initialized = false;

  /// Opens the Hive box. Safe to call multiple times. Must be awaited
  /// once (in `main()`) before the first [load] call.
  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
    _initialized = true;
  }

  /// Returns the last saved dashboard state, or `null` if nothing has
  /// been persisted yet (first launch).
  Future<Map<String, dynamic>?> load() async {
    if (!_initialized) await init();
    final raw = _box?.get(_stateKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      // Corrupt / incompatible data from a previous app version — start
      // fresh rather than crash the dashboard.
      return null;
    }
  }

  /// Persists the full dashboard state. Called after every mutation so
  /// a restart always resumes exactly where the user left off.
  Future<void> save(Map<String, dynamic> state) async {
    if (!_initialized) await init();
    await _box?.put(_stateKey, jsonEncode(state));
  }

  /// Wipes all persisted dashboard data (used by "Reset demo data").
  Future<void> clear() async {
    if (!_initialized) await init();
    await _box?.delete(_stateKey);
  }
}
