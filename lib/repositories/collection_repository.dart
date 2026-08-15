import '../core/network/api_client.dart';
import '../core/utils/app_exceptions.dart';
import '../models/gallery_collection_model.dart';

abstract class CollectionRepository {
  Future<List<GalleryCollectionModel>> fetchCollections();

  /// Persists a brand-new (empty) collection and returns the stored copy.
  Future<GalleryCollectionModel> createCollection(String name);

  /// Renames a collection. Throws [NotFoundException] if it no longer
  /// exists.
  Future<GalleryCollectionModel> renameCollection({
    required String collectionId,
    required String name,
  });

  /// Removes a collection. The albums inside it are left untouched —
  /// only the grouping goes away. Throws [NotFoundException] if it no
  /// longer exists.
  Future<void> deleteCollection(String collectionId);

  /// Appends one or more albums (by id) to the end of a collection.
  /// Albums already present are left as-is. Returns the updated
  /// collection.
  Future<GalleryCollectionModel> addAlbums({
    required String collectionId,
    required List<String> albumIds,
  });

  /// Removes a single album from a collection. Returns the updated
  /// collection.
  Future<GalleryCollectionModel> removeAlbum({
    required String collectionId,
    required String albumId,
  });

  /// Full replacement of album order within one collection — must
  /// contain exactly the album ids currently in the collection, just in
  /// the desired new order.
  Future<GalleryCollectionModel> reorderAlbums({
    required String collectionId,
    required List<String> albumIds,
  });
}

/// API-backed [CollectionRepository], talking to
/// `app/api/routes/collections.py` (`GET/POST/PATCH/DELETE /collections`,
/// plus the `/{id}/albums` membership endpoints) via [ApiClient] — same
/// pattern as [ApiAlbumRepository].
///
/// The backend models a "collection" as an ordered list of *album* ids
/// (`CollectionItem.album_id` is a real FK into the `Album` table, and
/// `POST /{id}/albums` validates each id against it) — not individual
/// media/photo ids. [GalleryCollectionModel.galleryIds] holds album ids
/// accordingly.
class ApiCollectionRepository implements CollectionRepository {
  ApiCollectionRepository({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  List<GalleryCollectionModel> _mapList(dynamic json) {
    final list = json as List<dynamic>;
    return list
        .map((e) => GalleryCollectionModel.fromApiJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<GalleryCollectionModel>> fetchCollections() async {
    final json = await _apiClient.get('/collections');
    return _mapList(json);
  }

  @override
  Future<GalleryCollectionModel> createCollection(String name) async {
    final json = await _apiClient.post('/collections', body: {'name': name});
    return GalleryCollectionModel.fromApiJson(json as Map<String, dynamic>);
  }

  @override
  Future<GalleryCollectionModel> renameCollection({
    required String collectionId,
    required String name,
  }) async {
    try {
      final json = await _apiClient.patch(
        '/collections/$collectionId',
        body: {'name': name},
      );
      return GalleryCollectionModel.fromApiJson(json as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        throw NotFoundException('Collection "$collectionId" no longer exists');
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteCollection(String collectionId) async {
    try {
      await _apiClient.delete('/collections/$collectionId');
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        throw NotFoundException('Collection "$collectionId" no longer exists');
      }
      rethrow;
    }
  }

  @override
  Future<GalleryCollectionModel> addAlbums({
    required String collectionId,
    required List<String> albumIds,
  }) async {
    try {
      final json = await _apiClient.post(
        '/collections/$collectionId/albums',
        body: {'album_ids': albumIds},
      );
      return GalleryCollectionModel.fromApiJson(json as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        throw NotFoundException('Collection "$collectionId" no longer exists');
      }
      rethrow;
    }
  }

  @override
  Future<GalleryCollectionModel> removeAlbum({
    required String collectionId,
    required String albumId,
  }) async {
    try {
      final json = await _apiClient.delete(
        '/collections/$collectionId/albums/$albumId',
      );
      return GalleryCollectionModel.fromApiJson(json as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        throw NotFoundException(
          'Collection "$collectionId" or album "$albumId" no longer exists',
        );
      }
      rethrow;
    }
  }

  @override
  Future<GalleryCollectionModel> reorderAlbums({
    required String collectionId,
    required List<String> albumIds,
  }) async {
    try {
      final json = await _apiClient.post(
        '/collections/$collectionId/albums/reorder',
        body: {'album_ids': albumIds},
      );
      return GalleryCollectionModel.fromApiJson(json as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        throw NotFoundException('Collection "$collectionId" no longer exists');
      }
      rethrow;
    }
  }
}
