import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../upload/upload_job_model.dart';

/// Hive-backed persistence for the Upload Queue.
///
/// Follows the same JSON-serialization approach as [MediaLocalStore]
/// to keep serialization simple, robust, and free from code generation requirements.
class UploadQueueLocalStore {
  static const String _boxName = 'upload_queue_box';
  static const String _stateKey = 'queue_state_v1';

  Box<String>? _box;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
    _initialized = true;
  }

  Future<List<UploadJobModel>> load() async {
    if (!_initialized) await init();

    final raw = _box?.get(_stateKey);
    if (raw == null || raw.isEmpty) return <UploadJobModel>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <UploadJobModel>[];

      return decoded
          .whereType<Map<String, dynamic>>()
          .map((e) => UploadJobModel.fromJson(e))
          .toList();
    } catch (_) {
      // Return empty list on corruption/incompatible formats
      return <UploadJobModel>[];
    }
  }

  Future<void> saveAll(List<UploadJobModel> jobs) async {
    if (!_initialized) await init();

    final jsonList = jobs.map((j) => j.toJson()).toList();
    await _box?.put(_stateKey, jsonEncode(jsonList));
  }

  Future<void> clear() async {
    if (!_initialized) await init();
    await _box?.delete(_stateKey);
  }
}
