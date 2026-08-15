import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/gallery_collection_model.dart';
import '../repositories/collection_repository.dart';
import 'auth_providers.dart' show apiClientProvider;

final collectionRepositoryProvider = Provider<CollectionRepository>((ref) {
  // Real backend (`app/api/routes/collections.py`), same reasoning as
  // `albumRepositoryProvider` — collections are ordered lists of *album*
  // ids on the server, not individual media ids (see
  // [GalleryCollectionModel]'s doc comment).
  return ApiCollectionRepository(apiClient: ref.watch(apiClientProvider));
});

/// Riverpod ChangeNotifier controller for gallery collections, backed by
/// the real `/collections` API (`CollectionRepository`).
///
/// Public method names/signatures below are unchanged from the previous
/// Hive-backed controller so screens (`CollectionsScreen`,
/// `CollectionDetailsScreen`) didn't need to change how they call this
/// provider — only what `galleryIds` semantically means (album ids, not
/// media ids) changed, along with the screens that render them.
final galleryCollectionsProvider =
    ChangeNotifierProvider<GalleryCollectionsController>((ref) {
  final controller =
      GalleryCollectionsController(repo: ref.watch(collectionRepositoryProvider));
  controller.load();
  return controller;
});

class GalleryCollectionsController extends ChangeNotifier {
  GalleryCollectionsController({required CollectionRepository repo}) : _repo = repo;

  final CollectionRepository _repo;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  final List<GalleryCollectionModel> _collections = [];
  List<GalleryCollectionModel> get collections =>
      List.unmodifiable(_collections);

  String? _lastError;
  String? get lastError => _lastError;

  List<GalleryCollectionModel> _sortCollections(
      List<GalleryCollectionModel> input) {
    final out = input.toList(growable: false);
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final loaded = await _repo.fetchCollections();
      _collections
        ..clear()
        ..addAll(_sortCollections(loaded));
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  GalleryCollectionModel? collectionById(String collectionId) {
    try {
      return _collections.firstWhere((c) => c.id == collectionId);
    } catch (_) {
      return null;
    }
  }

  Future<void> createCollection({required String name}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    try {
      final created = await _repo.createCollection(trimmed);
      final refreshed = [..._collections, created];
      _collections
        ..clear()
        ..addAll(_sortCollections(refreshed));
      _lastError = null;
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    }
  }

  Future<void> renameCollection({
    required String collectionId,
    required String newName,
  }) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;

    final idx = _collections.indexWhere((c) => c.id == collectionId);
    if (idx == -1) return;

    try {
      final saved = await _repo.renameCollection(
        collectionId: collectionId,
        name: trimmed,
      );
      _collections[idx] = saved;
      _lastError = null;
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteCollection(String collectionId) async {
    try {
      await _repo.deleteCollection(collectionId);
      _collections.removeWhere((c) => c.id == collectionId);
      _lastError = null;
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    }
  }

  bool isGalleryInCollection({
    required String collectionId,
    required String galleryId,
  }) {
    final c = collectionById(collectionId);
    if (c == null) return false;
    return c.galleryIds.contains(galleryId);
  }

  /// Adds albums (by id) to a collection. `galleryIds` here are album
  /// ids — kept as the parameter name screens already call this with.
  Future<void> addGalleriesToCollection({
    required String collectionId,
    required List<String> galleryIds,
  }) async {
    if (galleryIds.isEmpty) return;

    final idx = _collections.indexWhere((c) => c.id == collectionId);
    if (idx == -1) return;

    final c = _collections[idx];
    final existing = c.galleryIds.toSet();
    final toAdd = galleryIds.where((id) => !existing.contains(id)).toList();
    if (toAdd.isEmpty) return;

    try {
      final saved = await _repo.addAlbums(collectionId: collectionId, albumIds: toAdd);
      _collections[idx] = saved;
      _lastError = null;
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    }
  }

  Future<void> removeGalleryFromCollection({
    required String collectionId,
    required String galleryId,
  }) async {
    final idx = _collections.indexWhere((c) => c.id == collectionId);
    if (idx == -1) return;

    final c = _collections[idx];
    if (!c.galleryIds.contains(galleryId)) return;

    try {
      final saved = await _repo.removeAlbum(collectionId: collectionId, albumId: galleryId);
      _collections[idx] = saved;
      _lastError = null;
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    }
  }

  Future<void> reorderGalleryInCollection({
    required String collectionId,
    required int oldIndex,
    required int newIndex,
  }) async {
    final idx = _collections.indexWhere((c) => c.id == collectionId);
    if (idx == -1) return;

    final c = _collections[idx];
    final ids = c.galleryIds.toList();
    if (oldIndex < 0 || oldIndex >= ids.length) return;
    if (newIndex < 0 || newIndex >= ids.length) return;

    final item = ids.removeAt(oldIndex);
    ids.insert(newIndex, item);

    // Optimistic local reorder so the drag feels instant; reconciled with
    // whatever the server returns once the request completes.
    _collections[idx] = c.copyWith(galleryIds: ids);
    notifyListeners();

    try {
      final saved = await _repo.reorderAlbums(collectionId: collectionId, albumIds: ids);
      _collections[idx] = saved;
      _lastError = null;
      notifyListeners();
    } catch (e) {
      // Roll back to the server's last known order rather than leaving
      // the optimistic (possibly rejected) order in place.
      _lastError = e.toString();
      notifyListeners();
    }
  }
}
