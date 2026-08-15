import '../core/network/api_client.dart';
import '../models/album_model.dart';
import '../models/folder_model.dart';
import '../models/media_model.dart';

/// A single studio card — returned by `GET /client/studios`.
class SharedStudioModel {
  final String id;
  final String name;
  final String? logoUrl;
  final int sharedCount;

  const SharedStudioModel({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.sharedCount,
  });

  factory SharedStudioModel.fromApiJson(Map<String, dynamic> json) {
    return SharedStudioModel(
      id: json['id'] as String,
      name: json['name'] as String,
      logoUrl: json['logo_url'] as String?,
      sharedCount: json['shared_count'] as int? ?? 0,
    );
  }
}

/// Client-facing repository for the curated Shared Gallery feature.
///
/// Wraps three `/client/…` read endpoints that are separate from the
/// studio-owner endpoints so a client can never accidentally read (or
/// accidentally mutate) another studio's private data:
///
/// - `GET /client/studios` → [fetchSharedStudios]
/// - `GET /client/studios/{id}/folders` → [fetchSharedFolders]
/// - `GET /client/studios/{id}/albums` → [fetchSharedAlbums]
/// - `GET /client/studios/{id}/albums/{album_id}/media` → [fetchSharedAlbumMedia]
///
/// Also wraps the separate *connection*-based (as opposed to
/// share-based) gallery view:
///
/// - `GET /albums/shared-with-me` → [fetchConnectedAlbums]
abstract class ClientGalleryRepository {
  /// Lists every studio that currently has ≥1 active share with the
  /// current client. Ordered by most-recently-shared first.
  Future<List<SharedStudioModel>> fetchSharedStudios();

  /// Albums belonging to every studio this client has an *accepted*
  /// connection with (distinct from [fetchSharedStudios]'s per-album
  /// share model — see `ConnectedAlbumRead`'s docstring on the
  /// backend). Pass [studioId] to scope to a single connected studio;
  /// omit it to see albums across every studio the client is connected
  /// to at once — this is what powers Home's "recent"/"trending"-style
  /// sections, which span all connected studios.
  ///
  /// [mediaType]/[likedOnly] (Task 21.10, backed by `GET
  /// /albums/shared-with-me`'s Task 21.9 params) restrict to albums
  /// containing ≥1 matching media item — server-side, so callers that
  /// only need the filtered set (e.g. the Gallery tab's "Liked" chip)
  /// no longer have to fetch everything and filter client-side.
  Future<List<AlbumModel>> fetchConnectedAlbums({
    String? studioId,
    MediaType? mediaType,
    bool likedOnly = false,
  });

  /// Folder tree for [studioId], pruned to only folders that contain
  /// ≥1 shared album (ancestors of such folders are included to keep
  /// the tree navigable). Returns a flat list; callers reconstruct the
  /// tree from `parentId`.
  Future<List<FolderModel>> fetchSharedFolders(String studioId);

  /// Shared albums for [studioId] inside [folderId] (null = studio root).
  /// Reuses `AlbumRead` with `cover_thumbnail_url` exactly as the
  /// studio-owner endpoint does.
  Future<List<AlbumModel>> fetchSharedAlbums(String studioId, {String? folderId});

  /// Full media listing for a single shared album — backed by
  /// `GET /client/studios/{studio_id}/albums/{album_id}/media`.
  /// Paginated: pass [skip]/[limit] for subsequent pages (default
  /// [limit] is 100, matching the backend).
  ///
  /// [mediaType]/[likedOnly]/[sort] (Task 21.10, backed by Tasks
  /// 21.7–21.8's new query params) filter/order server-side.
  Future<List<MediaModel>> fetchSharedAlbumMedia(
    String studioId,
    String albumId, {
    int skip = 0,
    int limit = 100,
    MediaType? mediaType,
    bool likedOnly = false,
    String sort = 'recent',
  });

  /// Every media item the current client has liked, most-recently-liked
  /// first — backed by `GET /media/liked-by-me`. This is the actual
  /// client-safe "Favorites" data source; `GET /media?favorites_only`
  /// reads a studio's own `is_favorite` flag and 403s for a client.
  Future<List<MediaModel>> fetchLikedMedia({int skip = 0, int limit = 100});
}

class ApiClientGalleryRepository implements ClientGalleryRepository {
  ApiClientGalleryRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<SharedStudioModel>> fetchSharedStudios() async {
    final json = await _apiClient.get('/client/studios');
    return (json as List<dynamic>)
        .map((e) => SharedStudioModel.fromApiJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<AlbumModel>> fetchConnectedAlbums({
    String? studioId,
    MediaType? mediaType,
    bool likedOnly = false,
  }) async {
    final params = <String, String>{
      if (studioId != null) 'studio_id': studioId,
      if (mediaType != null) 'media_type': mediaType.name,
      if (likedOnly) 'liked_only': 'true',
    };
    final query = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final json = await _apiClient.get('/albums/shared-with-me$query');
    return (json as List<dynamic>)
        .map((e) => AlbumModel.fromConnectedApiJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<FolderModel>> fetchSharedFolders(String studioId) async {
    final json = await _apiClient.get('/client/studios/$studioId/folders');
    return (json as List<dynamic>)
        .map((e) => FolderModel.fromApiJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<AlbumModel>> fetchSharedAlbums(
    String studioId, {
    String? folderId,
  }) async {
    final query = folderId != null ? '?folder_id=$folderId' : '';
    final json = await _apiClient.get('/client/studios/$studioId/albums$query');
    return (json as List<dynamic>)
        .map((e) => AlbumModel.fromApiJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<MediaModel>> fetchSharedAlbumMedia(
    String studioId,
    String albumId, {
    int skip = 0,
    int limit = 100,
    MediaType? mediaType,
    bool likedOnly = false,
    String sort = 'recent',
  }) async {
    final params = <String, String>{
      'skip': '$skip',
      'limit': '$limit',
      'sort': sort,
      if (mediaType != null) 'media_type': mediaType.name,
      if (likedOnly) 'liked_only': 'true',
    };
    final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    final json = await _apiClient
        .get('/client/studios/$studioId/albums/$albumId/media?$query');
    return (json as List<dynamic>)
        .map((e) => MediaModel.fromApiJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<MediaModel>> fetchLikedMedia({int skip = 0, int limit = 100}) async {
    final json = await _apiClient.get('/media/liked-by-me?offset=$skip&limit=$limit');
    return (json as List<dynamic>)
        .map((e) => MediaModel.fromApiJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}