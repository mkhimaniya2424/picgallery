import '../core/network/api_client.dart';

/// One row of `AlbumClientShareRead`, as the studio sees it — result of
/// sharing an album/folder or listing what's currently shared with a
/// given client. Denormalized `albumName`/`albumCoverThumbnailUrl` come
/// straight from the backend response so the "manage sharing" UI never
/// needs a second round-trip per row.
class AlbumClientShare {
  final String id;
  final String albumId;
  final String clientId;
  final String studioId;
  final DateTime sharedAt;
  final DateTime? revokedAt;
  final String? albumName;
  final String? albumCoverThumbnailUrl;

  const AlbumClientShare({
    required this.id,
    required this.albumId,
    required this.clientId,
    required this.studioId,
    required this.sharedAt,
    this.revokedAt,
    this.albumName,
    this.albumCoverThumbnailUrl,
  });

  bool get isActive => revokedAt == null;

  factory AlbumClientShare.fromApiJson(Map<String, dynamic> json) {
    return AlbumClientShare(
      id: json['id'] as String,
      albumId: json['album_id'] as String,
      clientId: json['client_id'] as String,
      studioId: json['studio_id'] as String,
      sharedAt: DateTime.parse(json['shared_at'] as String),
      revokedAt: json['revoked_at'] == null
          ? null
          : DateTime.parse(json['revoked_at'] as String),
      albumName: json['album_name'] as String?,
      albumCoverThumbnailUrl: json['album_cover_thumbnail_url'] as String?,
    );
  }
}

/// Result of `POST /studio/shares/folder` — distinguishes newly-created
/// rows from ones that were already actively shared, mirroring
/// `BulkShareResult` on the backend.
class BulkShareResult {
  final List<AlbumClientShare> shares;
  final int createdCount;
  final int alreadySharedCount;

  const BulkShareResult({
    required this.shares,
    required this.createdCount,
    required this.alreadySharedCount,
  });

  factory BulkShareResult.fromApiJson(Map<String, dynamic> json) {
    return BulkShareResult(
      shares: (json['shares'] as List<dynamic>)
          .map((e) => AlbumClientShare.fromApiJson(e as Map<String, dynamic>))
          .toList(growable: false),
      createdCount: json['created_count'] as int,
      alreadySharedCount: json['already_shared_count'] as int,
    );
  }
}

/// Studio-side wrapper around `app/api/routes/studio_shares.py` — the
/// "share a gallery with a client" half of the curated Shared Gallery
/// feature. Read-only browsing of what's been shared *to* a client is
/// [ClientGalleryRepository]'s job instead; this repository only ever
/// creates/lists/revokes shares from the studio's side.
abstract class StudioSharesRepository {
  /// Shares one album with one connected client. Backed by
  /// `POST /studio/shares`. Idempotent — sharing an already-shared
  /// album just returns the existing active share.
  Future<AlbumClientShare> shareAlbum({
    required String albumId,
    required String clientId,
  });

  /// Shares every album directly inside [folderId] with one connected
  /// client. Backed by `POST /studio/shares/folder`.
  Future<BulkShareResult> shareFolder({
    required String folderId,
    required String clientId,
  });

  /// Soft-revokes a share (never a hard delete). Backed by
  /// `DELETE /studio/shares/{id}`.
  Future<void> revokeShare(String shareId);

  /// This studio's currently-active shares with [clientId]. Backed by
  /// `GET /studio/shares?client_id=`.
  Future<List<AlbumClientShare>> sharesForClient(String clientId);
}

class ApiStudioSharesRepository implements StudioSharesRepository {
  ApiStudioSharesRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<AlbumClientShare> shareAlbum({
    required String albumId,
    required String clientId,
  }) async {
    final json = await _apiClient.post(
      '/studio/shares',
      body: {'album_id': albumId, 'client_id': clientId},
    );
    return AlbumClientShare.fromApiJson(json as Map<String, dynamic>);
  }

  @override
  Future<BulkShareResult> shareFolder({
    required String folderId,
    required String clientId,
  }) async {
    final json = await _apiClient.post(
      '/studio/shares/folder',
      body: {'folder_id': folderId, 'client_id': clientId},
    );
    return BulkShareResult.fromApiJson(json as Map<String, dynamic>);
  }

  @override
  Future<void> revokeShare(String shareId) async {
    await _apiClient.delete('/studio/shares/$shareId');
  }

  @override
  Future<List<AlbumClientShare>> sharesForClient(String clientId) async {
    final json = await _apiClient.get('/studio/shares?client_id=$clientId');
    return (json as List<dynamic>)
        .map((e) => AlbumClientShare.fromApiJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}
