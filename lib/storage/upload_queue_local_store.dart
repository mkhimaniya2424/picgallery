import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../upload/upload_job_model.dart';

/// Hive-backed persistence for the Upload Queue.
///
/// Follows the same JSON-serialization approach as [MediaLocalStore]
/// to keep serialization simple, robust, and free from code generation requirements.
class UploadQueueLocalStore {
  static const String _boxName = 'upload_queue_box';
  static const String _stateKeyPrefix = 'queue_state_v1';
  static const String _lastUserIdKey = 'queue_state_v1_last_user_id';

  Box<String>? _box;
  bool _initialized = false;
  String? _userId;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
    _initialized = true;
  }

  String _keyFor(String userId) => '$_stateKeyPrefix:$userId';

  Future<void> scopeToUser(String userId) async {
    if (!_initialized) await init();

    final lastUserId = _box?.get(_lastUserIdKey);
    if (lastUserId != null && lastUserId != userId) {
      await _box?.delete(_keyFor(lastUserId));
    }
    await _box?.delete(_stateKeyPrefix);

    _userId = userId;
    await _box?.put(_lastUserIdKey, userId);
  }

  Future<void> clearForLogout() async {
    if (!_initialized) await init();

    final uid = _userId ?? _box?.get(_lastUserIdKey);
    if (uid != null) {
      await _box?.delete(_keyFor(uid));
    }
    await _box?.delete(_lastUserIdKey);
    _userId = null;
  }

  Future<List<UploadJobModel>> load() async {
    if (!_initialized) await init();
    final uid = _userId;
    if (uid == null) return <UploadJobModel>[];

    final raw = _box?.get(_keyFor(uid));
    if (raw == null || raw.isEmpty) return <UploadJobModel>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <UploadJobModel>[];

      return decoded
          .whereType<Map<String, dynamic>>()
          .map((e) => UploadJobModel.fromJson(e))
          .toList();
    } catch (_) {
      return <UploadJobModel>[];
    }
  }

  Future<void> saveAll(List<UploadJobModel> jobs) async {
    if (!_initialized) await init();
    final uid = _userId;
    if (uid == null) return;

    final jsonList = jobs.map((j) => j.toJson()).toList();
    await _box?.put(_keyFor(uid), jsonEncode(jsonList));
  }

  Future<void> clear() async {
    if (!_initialized) await init();
    final uid = _userId;
    if (uid == null) return;
    await _box?.delete(_keyFor(uid));
  }
}
