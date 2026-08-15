import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/download_history_model.dart';

/// Hive-backed local persistence for "Download History".
///
/// Two independent things live here:
/// - A read-only mirror of the last successful `GET /download-history`
///   response, served when the app is offline (same pattern as
///   `HiveMediaRepository` behind `CachingMediaRepository`).
/// - A set of locally "dismissed" event ids. The backend has no DELETE
///   endpoint for download history (`app/api/routes/download_history.py`
///   only exposes POST/GET/GET stats), so Delete/Clear can't remove the
///   row server-side — instead we remember which ids the user dismissed
///   and filter them back out of every future API fetch, so a delete
///   still feels permanent even though the server still has the row.
class DownloadHistoryLocalStore {
  static const String _boxName = 'download_history_box';
  static const String _cacheKey = 'download_history_cache_v1';
  static const String _dismissedKey = 'download_history_dismissed_v1';

  Box<String>? _box;
  bool _initialized = false;

  /// Safe to call multiple times.
  ///
  /// Note: the project already initializes Hive in `main.dart`.
  /// We keep this method consistent with other stores, but it will be
  /// guarded by [_initialized] so it won’t re-open Hive boxes repeatedly.
  Future<void> init() async {
    if (_initialized) return;
    _box = await Hive.openBox<String>(_boxName);
    _initialized = true;
  }

  // -------------------------------------------------------------------
  // Offline read cache (mirrors the last successful API fetch)
  // -------------------------------------------------------------------

  Future<List<DownloadHistoryModel>> loadCache() async {
    if (!_initialized) await init();

    final raw = _box?.get(_cacheKey);
    if (raw == null || raw.isEmpty) return <DownloadHistoryModel>[];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return <DownloadHistoryModel>[];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(DownloadHistoryModel.fromJson)
        .toList();
  }

  Future<void> saveCache(List<DownloadHistoryModel> history) async {
    if (!_initialized) await init();

    final json = history.map((e) => e.toJson()).toList();
    await _box?.put(_cacheKey, jsonEncode(json));
  }

  // -------------------------------------------------------------------
  // Locally-dismissed ids (Delete / Clear History workaround — see
  // class doc: there is no backend DELETE for download history)
  // -------------------------------------------------------------------

  Future<Set<String>> loadDismissedIds() async {
    if (!_initialized) await init();

    final raw = _box?.get(_dismissedKey);
    if (raw == null || raw.isEmpty) return <String>{};

    final decoded = jsonDecode(raw);
    if (decoded is! List) return <String>{};
    return decoded.whereType<String>().toSet();
  }

  Future<void> saveDismissedIds(Set<String> ids) async {
    if (!_initialized) await init();
    await _box?.put(_dismissedKey, jsonEncode(ids.toList()));
  }

  Future<void> clear() async {
    if (!_initialized) await init();
    await _box?.delete(_cacheKey);
    await _box?.delete(_dismissedKey);
  }
}
