import '../core/network/api_client.dart';
import '../core/utils/app_exceptions.dart';
import '../models/studio_model.dart';
import '../storage/studio_local_store.dart';

abstract class StudioDirectoryRepository {
  Future<List<StudioModel>> fetchStudios();
  Future<void> saveStudio(StudioModel studio);
  Future<void> clear();

  /// Studios the current client has favorited, most-recently-favorited
  /// first (matches `GET /studios/favorites`'s ordering).
  Future<List<StudioModel>> fetchFavoriteStudios();

  /// Marks [studioId] as favorited for the current client. Idempotent —
  /// favoriting an already-favorited studio is a no-op server-side.
  Future<void> favoriteStudio(String studioId);

  /// Removes [studioId] from the current client's favorites. Throws
  /// [NotFoundException] if it wasn't favorited to begin with.
  Future<void> unfavoriteStudio(String studioId);

  /// The full Discover Studios directory — every active studio, with
  /// [StudioModel.connectionStatus]/[StudioModel.isFavorite] already
  /// computed relative to the current client. Backed by `GET /studios`.
  Future<List<StudioModel>> fetchDirectory();

  /// Sends a connection request from the current client to [studioId].
  /// Backed by `POST /studios/{id}/connect`. Throws [ApiException] if
  /// a request is already pending or the two are already connected.
  Future<void> connectToStudio(String studioId);

  /// Withdraws the current client's own still-pending request to
  /// [studioId]. Backed by `DELETE /studios/{id}/connect`. Throws
  /// [NotFoundException] if there's no pending request to withdraw.
  Future<void> withdrawStudioRequest(String studioId);
}

class LocalStudioDirectoryRepository implements StudioDirectoryRepository {
  final StudioLocalStore _store;
  final List<StudioModel> _studios = [];

  LocalStudioDirectoryRepository(this._store);

  @override
  Future<List<StudioModel>> fetchStudios() async {
    if (_studios.isEmpty) {
      final loaded = await _store.load();
      _studios.addAll(loaded);
    }
    return List.unmodifiable(_studios);
  }

  @override
  Future<void> saveStudio(StudioModel studio) async {
    // Ensure we load studios before saving/updating
    await fetchStudios();
    final index = _studios.indexWhere((s) => s.id == studio.id);
    if (index != -1) {
      _studios[index] = studio;
    } else {
      _studios.add(studio);
    }
    await _store.saveAll(_studios);
  }

  @override
  Future<void> clear() async {
    _studios.clear();
    await _store.clear();
  }

  @override
  Future<List<StudioModel>> fetchFavoriteStudios() async {
    final all = await fetchStudios();
    return all.where((s) => s.isFavorite).toList();
  }

  @override
  Future<void> favoriteStudio(String studioId) async {
    await fetchStudios();
    final index = _studios.indexWhere((s) => s.id == studioId);
    if (index == -1) {
      throw NotFoundException('Studio "$studioId" no longer exists');
    }
    _studios[index] = _studios[index].copyWith(isFavorite: true);
    await _store.saveAll(_studios);
  }

  @override
  Future<void> unfavoriteStudio(String studioId) async {
    await fetchStudios();
    final index = _studios.indexWhere((s) => s.id == studioId);
    if (index == -1) {
      throw NotFoundException('Studio "$studioId" no longer exists');
    }
    _studios[index] = _studios[index].copyWith(isFavorite: false);
    await _store.saveAll(_studios);
  }

  @override
  Future<List<StudioModel>> fetchDirectory() => fetchStudios();

  @override
  Future<void> connectToStudio(String studioId) async {
    await fetchStudios();
    final index = _studios.indexWhere((s) => s.id == studioId);
    if (index == -1) {
      throw NotFoundException('Studio "$studioId" no longer exists');
    }
    _studios[index] = _studios[index].copyWith(connectionStatus: StudioConnectionStatus.pending);
    await _store.saveAll(_studios);
  }

  @override
  Future<void> withdrawStudioRequest(String studioId) async {
    await fetchStudios();
    final index = _studios.indexWhere((s) => s.id == studioId);
    if (index == -1) {
      throw NotFoundException('Studio "$studioId" no longer exists');
    }
    _studios[index] = _studios[index].copyWith(connectionStatus: StudioConnectionStatus.notConnected);
    await _store.saveAll(_studios);
  }
}

/// API-backed studio directory + favorites, talking to
/// `app/api/routes/studios.py` via [ApiClient] — mirrors
/// [ApiAlbumRepository]'s shape in `album_repository.dart`.
///
/// `fetchStudios`/`saveStudio`/`clear` are the old local-cache-shaped
/// methods from [StudioDirectoryRepository]'s original (Hive-only)
/// design — nothing calls them anymore now that [fetchDirectory] backs
/// the real `GET /studios` endpoint, so they stay intentionally
/// unimplemented rather than papered over with a fake local cache.
class ApiStudioRepository implements StudioDirectoryRepository {
  ApiStudioRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<StudioModel>> fetchStudios() {
    throw UnimplementedError(
      'ApiStudioRepository does not back the studio directory — '
      'only favorites (fetchFavoriteStudios/favoriteStudio/unfavoriteStudio).',
    );
  }

  @override
  Future<void> saveStudio(StudioModel studio) {
    throw UnimplementedError(
      'ApiStudioRepository does not back the studio directory — '
      'only favorites (fetchFavoriteStudios/favoriteStudio/unfavoriteStudio).',
    );
  }

  @override
  Future<void> clear() {
    throw UnimplementedError(
      'ApiStudioRepository does not back the studio directory — '
      'only favorites (fetchFavoriteStudios/favoriteStudio/unfavoriteStudio).',
    );
  }

  @override
  Future<List<StudioModel>> fetchFavoriteStudios() async {
    final json = await _apiClient.get('/studios/favorites');
    final list = json as List<dynamic>;
    return list
        .map((e) => StudioModel.fromFavoriteApiJson(
              (e as Map<String, dynamic>)['studio'] as Map<String, dynamic>,
            ))
        .toList(growable: false);
  }

  @override
  Future<void> favoriteStudio(String studioId) async {
    try {
      await _apiClient.post('/studios/$studioId/favorite');
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        throw NotFoundException('Studio "$studioId" no longer exists');
      }
      rethrow;
    }
  }

  @override
  Future<void> unfavoriteStudio(String studioId) async {
    try {
      await _apiClient.delete('/studios/$studioId/favorite');
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        throw const NotFoundException('This studio isn\'t in your favorites.');
      }
      rethrow;
    }
  }

  @override
  Future<List<StudioModel>> fetchDirectory() async {
    final json = await _apiClient.get('/studios');
    final list = json as List<dynamic>;
    return list
        .map((e) => StudioModel.fromDirectoryApiJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Throws [ApiException] as-is (rather than wrapping) when the
  /// request is a 400 — "already pending"/"already connected" carry
  /// server-authored copy in [ApiException.message] that's already
  /// fit to show the user, same as how [StudioNotifier] surfaces
  /// [favoritesError] today.
  @override
  Future<void> connectToStudio(String studioId) async {
    try {
      await _apiClient.post('/studios/$studioId/connect');
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        throw NotFoundException('Studio "$studioId" no longer exists');
      }
      rethrow;
    }
  }

  @override
  Future<void> withdrawStudioRequest(String studioId) async {
    try {
      await _apiClient.delete('/studios/$studioId/connect');
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        throw const NotFoundException('No pending request to this studio.');
      }
      rethrow;
    }
  }
}