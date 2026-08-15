import '../core/network/api_client.dart';
import '../core/utils/app_exceptions.dart';
import '../models/album_model.dart';

abstract class AlbumRepository {
  Future<List<AlbumModel>> fetchAlbums();

  /// Persists a brand-new album and returns the stored copy.
  Future<AlbumModel> createAlbum(AlbumModel album);

  /// Persists changes to an existing album (matched by [AlbumModel.id])
  /// and returns the stored copy. Throws [NotFoundException] if the
  /// album no longer exists.
  Future<AlbumModel> updateAlbum(AlbumModel album);

  /// Removes an album. Throws [NotFoundException] if it no longer exists.
  Future<void> deleteAlbum(String id);
}

/// Pure in-memory repository with lightweight simulated latency.
///
/// No network, no db, no local persistence (per brief). Starts with an
/// EMPTY collection — no seed/demo/placeholder albums — and acts as the
/// single mutable source of truth for albums so create/update/delete
/// survive across `AlbumListController` rebuilds within the same app
/// session. Swapping this for a real backend (Firebase/REST/etc.) later
/// means writing one new class that implements [AlbumRepository] and
/// wiring it into `albumRepositoryProvider` — no screen changes needed.
class InMemoryAlbumRepository implements AlbumRepository {
  InMemoryAlbumRepository({this.latency = const Duration(milliseconds: 520)});

  final Duration latency;

  final List<AlbumModel> _albums = [];

  @override
  Future<List<AlbumModel>> fetchAlbums() async {
    await Future.delayed(latency);
    // Return a copy so callers can't mutate our internal list by
    // accident (they must go through create/update/delete).
    return List<AlbumModel>.from(_albums);
  }

  @override
  Future<AlbumModel> createAlbum(AlbumModel album) async {
    await Future.delayed(latency ~/ 2);
    _albums.add(album);
    return album;
  }

  @override
  Future<AlbumModel> updateAlbum(AlbumModel album) async {
    await Future.delayed(latency ~/ 2);
    final idx = _albums.indexWhere((a) => a.id == album.id);
    if (idx == -1) {
      throw NotFoundException('Album "${album.id}" no longer exists');
    }
    _albums[idx] = album;
    return album;
  }

  @override
  Future<void> deleteAlbum(String id) async {
    await Future.delayed(latency ~/ 2);
    final existed = _albums.any((a) => a.id == id);
    if (!existed) {
      throw NotFoundException('Album "$id" no longer exists');
    }
    _albums.removeWhere((a) => a.id == id);
  }
}

/// API-backed [AlbumRepository], talking to `app/api/routes/albums.py`
/// (`GET/POST/PATCH/DELETE /albums`) via [ApiClient] — the real
/// counterpart [InMemoryAlbumRepository]'s doc comment already
/// anticipated ("writing one new class that implements
/// [AlbumRepository] and wiring it into `albumRepositoryProvider`").
///
/// Every album/folder created against this repository is a real row on
/// the server, with a real server-generated UUID `id` — unlike
/// [InMemoryAlbumRepository]'s client-side placeholder ids (e.g.
/// `al-<timestamp>`), which are never valid UUIDs and make any
/// downstream call that expects a UUID (like `POST /media/upload`'s
/// `album_id` query param) fail server-side validation.
class ApiAlbumRepository implements AlbumRepository {
  ApiAlbumRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  List<AlbumModel> _mapList(dynamic json) {
    final list = json as List<dynamic>;
    return list
        .map((e) => AlbumModel.fromApiJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<AlbumModel>> fetchAlbums() async {
    final json = await _apiClient.get('/albums');
    return _mapList(json);
  }

  @override
  Future<AlbumModel> createAlbum(AlbumModel album) async {
    final json = await _apiClient.post('/albums', body: album.toCreateJson());
    return AlbumModel.fromApiJson(json as Map<String, dynamic>);
  }

  @override
  Future<AlbumModel> updateAlbum(AlbumModel album) async {
    // The caller (AlbumNotifier) already resolved the final desired
    // state into [album] itself — a null description/folderId there
    // means "should be cleared", not "leave untouched" (this repo
    // always sends every field, never a partial diff), so derive the
    // explicit clear_* flags the backend requires from that nullness.
    final body = album.toUpdateJson(
      clearDescription: album.description == null,
      clearFolder: album.folderId == null,
    );
    try {
      final json = await _apiClient.patch('/albums/${album.id}', body: body);
      return AlbumModel.fromApiJson(json as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        throw NotFoundException('Album "${album.id}" no longer exists');
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteAlbum(String id) async {
    // Both delete-confirmation dialogs in the UI (Albums List, Edit
    // Album) already warn the user up front — "This will permanently
    // remove ... and its N photos. This can't be undone." — i.e. the
    // app's contract is a cascade delete, not a rejection. The backend
    // mirrors that via `force=true` (default `force=false` returns 409
    // if the album still has active media, as a safety net for callers
    // that *don't* pre-warn); since this repo's callers already do,
    // always pass it.
    try {
      await _apiClient.delete('/albums/$id?force=true');
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        throw NotFoundException('Album "$id" no longer exists');
      }
      rethrow;
    }
  }
}