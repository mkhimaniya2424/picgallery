import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/media_comment.dart';
import '../models/media_like.dart';

/// Hive-backed local persistence for likes + comments per media.
///
/// Uses one Hive box with two string keys, storing JSON arrays.
class MediaLikesCommentsLocalStore {
  static const String _boxName = 'media_likes_comments_box';
  static const String _likesKey = 'likes_v1';
  static const String _commentsKey = 'comments_v1';

  Box<String>? _box;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
    _initialized = true;
  }

  Future<List<MediaLike>> loadLikes() async {
    if (!_initialized) await init();
    final raw = _box?.get(_likesKey);
    if (raw == null || raw.isEmpty) return <MediaLike>[];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return <MediaLike>[];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(MediaLike.fromJson)
        .toList(growable: false);
  }

  Future<List<MediaComment>> loadComments() async {
    if (!_initialized) await init();
    final raw = _box?.get(_commentsKey);
    if (raw == null || raw.isEmpty) return <MediaComment>[];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return <MediaComment>[];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(MediaComment.fromJson)
        .toList(growable: false);
  }

  Future<void> saveLikes(List<MediaLike> likes) async {
    if (!_initialized) await init();
    final json = likes.map((l) => l.toJson()).toList();
    await _box?.put(_likesKey, jsonEncode(json));
  }

  Future<void> saveComments(List<MediaComment> comments) async {
    if (!_initialized) await init();
    final json = comments.map((c) => c.toJson()).toList();
    await _box?.put(_commentsKey, jsonEncode(json));
  }

  Future<void> clearAll() async {
    if (!_initialized) await init();
    await _box?.delete(_likesKey);
    await _box?.delete(_commentsKey);
  }
}
