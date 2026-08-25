import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../models/media_comment.dart';
import '../models/media_like.dart';
import '../models/media_model.dart';
import '../providers/auth_providers.dart' show apiClientProvider, authStateProvider;
import '../storage/media_likes_comments_local_store.dart';

/// Provider for likes + comments UI in MediaDetails.
///
/// API-backed: toggles likes and CRUDs comments via the backend endpoints
/// (POST /media/{id}/like, GET /media/{id}/comments, etc.), with a
/// fallback to the local Hive store when offline. This provider replaces
/// the previous Hive-only stub (Task 23 completion).
final mediaLikesCommentsProvider =
    ChangeNotifierProvider<MediaLikesCommentsController>((ref) {
  final apiClient = ref.read(apiClientProvider);
  final store = MediaLikesCommentsLocalStore();
  final controller = MediaLikesCommentsController(
    apiClient: apiClient,
    store: store,
    ref: ref,
  );
  controller.load();
  return controller;
});

class MediaLikesCommentsController extends ChangeNotifier {
  MediaLikesCommentsController({
    required ApiClient apiClient,
    required MediaLikesCommentsLocalStore store,
    required Ref ref,
  })  : _apiClient = apiClient,
        _store = store,
        _ref = ref;

  final ApiClient _apiClient;
  final MediaLikesCommentsLocalStore _store;
  final Ref _ref;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _lastError;
  String? get lastError => _lastError;

  /// Maps mediaId -> {liked, likeCount}. Cached so the grid/details don't
  /// re-fetch on every build.
  final Map<String, ({bool liked, int count})> _likeStates = {};

  final List<MediaComment> _comments = [];
  final List<MediaLike> _likes = [];

  /// mediaIds whose comments have already been requested at least once —
  /// lets callers (e.g. [MediaDetailsScreen]'s `Consumer`, which re-runs
  /// its builder on every rebuild) avoid re-triggering [fetchComments]
  /// every single build.
  final Set<String> _fetchedCommentsFor = {};
  final Set<String> _fetchedLikesFor = {};

  /// Whether [fetchComments] has already been called for [mediaId] this
  /// session — check this before calling it again from a `build` method.
  bool hasFetchedComments(String mediaId) => _fetchedCommentsFor.contains(mediaId);

  bool hasFetchedLikes(String mediaId) => _fetchedLikesFor.contains(mediaId);

  // -------------------------------------------------------------------
  // Likes
  // -------------------------------------------------------------------

  /// Returns a cached like state for [mediaId], or defaults (false, 0).
  ({bool liked, int count}) likeStateFor(String mediaId) =>
      _likeStates[mediaId] ?? (liked: false, count: 0);

  bool isLikedByMe(String mediaId) => likeStateFor(mediaId).liked;

  /// Primes the like cache for [media] from the server-provided
  /// `like_count`/`is_liked_by_me` fields (`MediaRead`) the first time
  /// this media is shown — e.g. from `MediaDetailsScreen`, right before
  /// [likeStateFor] is read, so the like button never has to fall back
  /// to the (false, 0) default just because the user hasn't personally
  /// tapped it yet this session.
  ///
  /// No-op once a state is already cached for [mediaId]: after the
  /// first seed (or any real toggle), the cache is the source of truth
  /// and must not be overwritten by a stale value from a later rebuild.
  void seedLikeState(MediaModel media) {
    if (_likeStates.containsKey(media.id)) return;
    _likeStates[media.id] = (liked: media.isLikedByMe, count: media.likeCount);
  }

  /// Toggles a like via `POST /media/{id}/like`. Updates local cache
  /// optimistically, then corrects with the server response.
  Future<void> toggleLike(String mediaId) async {
    final current = _likeStates[mediaId] ?? (liked: false, count: 0);

    // Optimistic update
    _likeStates[mediaId] = (
      liked: !current.liked,
      count: current.liked
          ? (current.count > 0 ? current.count - 1 : 0)
          : current.count + 1,
    );
    notifyListeners();

    try {
      final response = await _apiClient.post('/media/$mediaId/like');
      final body = response as Map<String, dynamic>;
      _likeStates[mediaId] = (
        liked: body['liked'] as bool,
        count: body['like_count'] as int,
      );
    } on ApiException catch (e) {
      // Revert optimistic update on failure
      _likeStates[mediaId] = current;
      _lastError = e.message;
    } catch (e) {
      _likeStates[mediaId] = current;
      _lastError = e.toString();
      _lastError = e.toString();
    }
    notifyListeners();
  }

  List<MediaLike> likesForMedia(String mediaId) =>
      _likes.where((l) => l.mediaId == mediaId).toList(growable: false);

  Future<void> fetchLikes(String mediaId) async {
    _fetchedLikesFor.add(mediaId);
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.get('/media/$mediaId/likes');
      final list = response as List<dynamic>;
      _likes.removeWhere((l) => l.mediaId == mediaId);
      _likes.addAll(
        list
            .map((e) => MediaLike.fromApiJson(e as Map<String, dynamic>))
            .toList(),
      );
      _lastError = null;
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // -------------------------------------------------------------------
  // Comments
  // -------------------------------------------------------------------

  List<MediaComment> commentsForMedia(String mediaId) =>
      _comments.where((c) => c.mediaId == mediaId).toList(growable: false);

  /// Fetches comments from the API for [mediaId], or falls back to Hive
  /// if the network is unavailable.
  Future<void> fetchComments(String mediaId) async {
    _fetchedCommentsFor.add(mediaId);
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiClient.get('/media/$mediaId/comments');
      final list = response as List<dynamic>;
      // Remove old comments for this media, add new ones
      _comments.removeWhere((c) => c.mediaId == mediaId);
      _comments.addAll(
        list
            .map((e) => MediaComment.fromApiJson(e as Map<String, dynamic>))
            .toList(),
      );
      _lastError = null;
    } on ApiException {
      // Offline: fall back to Hive cache
      _lastError = 'Could not load comments from server. Showing cached.';
      final cached = await _store.loadComments();
      _comments
        ..clear()
        ..addAll(cached.where((c) => c.mediaId == mediaId));
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// POST /media/{id}/comments — creates a new comment.
  Future<void> addComment({
    required String mediaId,
    required String text,
    String? parentId,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _isLoading = true;
    notifyListeners();

    try {
      final body = <String, dynamic>{'text': trimmed};
      if (parentId != null) body['parent_id'] = parentId;

      final response =
          await _apiClient.post('/media/$mediaId/comments', body: body);
      final created =
          MediaComment.fromApiJson(response as Map<String, dynamic>);
      _comments.add(created);
      _lastError = null;
    } on ApiException catch (e) {
      _lastError = e.message;
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// PATCH /media/{id}/comments/{commentId}
  Future<void> editOwnComment({
    required String commentId,
    required String newText,
  }) async {
    final trimmed = newText.trim();
    if (trimmed.isEmpty) return;

    _isLoading = true;
    notifyListeners();

    try {
      final idx = _comments.indexWhere((c) => c.id == commentId);
      if (idx == -1) return;

      final mediaId = _comments[idx].mediaId;
      final response = await _apiClient.patch(
        '/media/$mediaId/comments/$commentId',
        body: {'text': trimmed},
      );
      _comments[idx] =
          MediaComment.fromApiJson(response as Map<String, dynamic>);
      _lastError = null;
    } on ApiException catch (e) {
      _lastError = e.message;
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// DELETE /media/{id}/comments/{commentId} — deletes the comment and
  /// all its nested replies (handled server-side).
  Future<void> deleteOwnComment({
    required String commentId,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final idx = _comments.indexWhere((c) => c.id == commentId);
      if (idx == -1) return;

      final mediaId = _comments[idx].mediaId;
      await _apiClient.delete('/media/$mediaId/comments/$commentId');

      // Remove from local list — the server handles cascading deletes.
      _comments.removeAt(idx);
      _lastError = null;
    } on ApiException catch (e) {
      _lastError = e.message;
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads like states from the API for all media the user can see.
  /// Called once on controller creation.
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Like states are fetched per-media when the user opens details.
      // For the initial load, we just ensure the local store is ready.
      // Just warm up the local store; fetchComments will populate per-media on demand.
      await _store.loadComments();
      _lastError = null;
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Returns the current user's id from auth state, or empty string if
  /// not logged in.
  String get currentUserId {
    final authState = _ref.read(authStateProvider);
    return authState.user?.id ?? '';
  }
}