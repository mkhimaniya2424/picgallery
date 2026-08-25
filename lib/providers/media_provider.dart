import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/media_model.dart';
import '../models/edit_recipe.dart';
import '../repositories/media_repository.dart';
import '../repositories/api_media_repository.dart';
import '../repositories/caching_media_repository.dart';
import '../storage/media_ui_filters_local_store.dart';
import 'album_provider.dart';
import 'auth_providers.dart' show apiClientProvider, AuthState, authStateProvider;

enum MediaDateFilterOption {
  all,
  last7,
  last30,
  last90,
}

enum MediaSizeFilterOption {
  all,
  small,
  medium,
  large,
}

enum MediaSortOption {
  recent,
  name,
  size,
  duration,
}

enum MediaFilterOption {
  all,
  favorites,
}

/// Controller/state for Photo/Video grids.
///
/// - Mirrors AlbumListController patterns: loading/error/search/sort/filter.
/// - Includes multi-selection plumbing for future UI.
class MediaListController extends ChangeNotifier {
  MediaListController({required MediaRepository repository, required Ref ref})
      : _repo = repository,
        _ref = ref;

  final MediaRepository _repo;
  final Ref _ref;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _lastError;
  String? get lastError => _lastError;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  MediaSortOption _sortOption = MediaSortOption.recent;
  MediaSortOption get sortOption => _sortOption;

  MediaFilterOption _filterOption = MediaFilterOption.all;
  MediaFilterOption get filterOption => _filterOption;

  /// When set, returns media only for that album.
  String? _albumId;
  String? get albumId => _albumId;

  /// When set, returns media only for that folder.
  String? _folderId;
  String? get folderId => _folderId;

  /// Type filter (photo/video/all via nullable).
  MediaType? _type;
  MediaType? get type => _type;

  String? _likedByClientId;
  String? get likedByClientId => _likedByClientId;

  final List<MediaModel> _allMedia = [];
  List<MediaModel> get allMedia => List.unmodifiable(_allMedia);

  /// Multi-selection support (IDs only) for future UI.
  final Set<String> _selectedIds = {};
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);

  bool get isSelectionMode => _selectedIds.isNotEmpty;

  DateTime? _dateFrom;
  DateTime? get dateFrom => _dateFrom;

  DateTime? _dateTo;
  DateTime? get dateTo => _dateTo;

  int? _sizeMin;
  int? get sizeMin => _sizeMin;

  int? _sizeMax;
  int? get sizeMax => _sizeMax;

  final MediaUiFiltersLocalStore _uiStore = MediaUiFiltersLocalStore();

  bool _uiLoaded = false;

  Future<void> _loadUiStateIfNeeded() async {
    if (_uiLoaded) return;
    _uiLoaded = true;

    final state = await _uiStore.load();
    if (state == null) return;

    _searchQuery = state.searchQuery;
    _albumId = state.albumId;
    _folderId = state.folderId;

    _type = state.type == null
        ? null
        : (state.type == MediaType.video.name
            ? MediaType.video
            : MediaType.photo);

    _filterOption = state.filterOption == MediaFilterOption.favorites.name
        ? MediaFilterOption.favorites
        : MediaFilterOption.all;

    _sortOption = switch (state.sortOption) {
      'name' => MediaSortOption.name,
      'size' => MediaSortOption.size,
      'duration' => MediaSortOption.duration,
      _ => MediaSortOption.recent,
    };

    _sizeMin = state.sizeMin;
    _sizeMax = state.sizeMax;

    _dateFrom = state.dateFrom;
    _dateTo = state.dateTo;
  }

  Future<void> _persistUiState() async {
    final state = MediaUiFiltersState(
      searchQuery: _searchQuery,
      albumId: _albumId,
      folderId: _folderId,
      type: _type?.name,
      filterOption: _filterOption.name,
      sortOption: _sortOption.name,
      sizeMin: _sizeMin,
      sizeMax: _sizeMax,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
    );

    await _uiStore.save(state);
  }

  List<MediaModel> get filteredMedia {
    Iterable<MediaModel> list = _allMedia;

    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      // Filename search is always supported.
      // Folder search is supported by matching folderId when present.
      list = list.where((m) {
        final fileOk = m.fileName.toLowerCase().contains(q);
        final folderOk = (m.folderId ?? '').toLowerCase().contains(q);
        return fileOk || folderOk;
      });
    }

    if (_filterOption == MediaFilterOption.favorites) {
      list = list.where((m) => m.isFavorite);
    }

    if (_albumId != null) {
      list = list.where((m) => m.albumId == _albumId);
    }

    if (_folderId != null) {
      list = list.where((m) => m.folderId == _folderId);
    }

    if (_type != null) {
      list = list.where((m) => m.type == _type);
    }

    if (_dateFrom != null) {
      list = list.where((m) => !m.modifiedAt.isBefore(_dateFrom!));
    }

    if (_dateTo != null) {
      list = list.where(
          (m) => m.modifiedAt.isBefore(_dateTo!.add(const Duration(days: 1))));
    }

    if (_sizeMin != null) {
      list = list.where((m) => m.size >= _sizeMin!);
    }

    if (_sizeMax != null) {
      list = list.where((m) => m.size <= _sizeMax!);
    }

    final out = list.toList();
    switch (_sortOption) {
      case MediaSortOption.recent:
        out.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
        break;
      case MediaSortOption.name:
        out.sort((a, b) =>
            a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()));
        break;
      case MediaSortOption.size:
        out.sort((a, b) => b.size.compareTo(a.size));
        break;
      case MediaSortOption.duration:
        out.sort((a, b) => (b.duration?.inMilliseconds ?? -1)
            .compareTo(a.duration?.inMilliseconds ?? -1));
        break;
    }

    return out;
  }

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      await _loadUiStateIfNeeded();
      final media = await _repo.fetchMedia(
        likedByClientId: _likedByClientId,
      );
      _allMedia
        ..clear()
        ..addAll(media);
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setLikedByClientId(String? id) {
    if (_likedByClientId == id) return;
    _likedByClientId = id;
    notifyListeners();
  }

  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
    // Fire-and-forget persistence.
    // ignore: unawaited_futures
    _persistUiState();
  }

  void setSortOption(MediaSortOption value) {
    _sortOption = value;
    notifyListeners();
    // ignore: unawaited_futures
    _persistUiState();
  }

  void setFilterOption(MediaFilterOption value) {
    _filterOption = value;
    notifyListeners();
    // ignore: unawaited_futures
    _persistUiState();
  }

  void setAlbum(String? albumId) {
    _albumId = albumId;
    notifyListeners();
  }

  void setFolder(String? folderId) {
    _folderId = folderId;
    notifyListeners();
  }

  void setType(MediaType? type) {
    _type = type;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Selection
  // ---------------------------------------------------------------------

  void toggleSelected(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void selectAll() {
    // Select current filtered view for predictable UX.
    _selectedIds
      ..clear()
      ..addAll(filteredMedia.map((m) => m.id));
    notifyListeners();
  }

  void deselectAll() {
    _selectedIds.clear();
    notifyListeners();
  }

  void clearSelection() => deselectAll();

  // ---------------------------------------------------------------------
  // Album photo-count sync
  // ---------------------------------------------------------------------

  /// Keeps [AlbumModel.photoCount] accurate whenever media is added,
  /// deleted, restored, moved, or copied, so every entry point (Album
  /// Details FAB, Media Grid, Media Details) reflects the change
  /// immediately without each screen having to remember to call
  /// `albumProvider` itself.
  Future<void> _adjustAlbumPhotoCount(String? albumId, int delta) async {
    if (albumId == null || delta == 0) return;
    try {
      await _ref.read(albumProvider).adjustPhotoCount(albumId, delta);
    } catch (_) {
      // albumProvider not ready (e.g. isolated tests) — safe to ignore,
      // mirrors AlbumListController._syncFolderCounts' defensive pattern.
    }
  }

  // ---------------------------------------------------------------------
  // Favorites
  // ---------------------------------------------------------------------

  Future<void> toggleFavorite(String id) async {
    try {
      await _repo.toggleFavorite(id);
      final idx = _allMedia.indexWhere((m) => m.id == id);
      if (idx != -1) {
        _allMedia[idx] = _allMedia[idx].copyWith(
          isFavorite: !_allMedia[idx].isFavorite,
          modifiedAt: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------
  // CRUD operations (metadata only)
  // ---------------------------------------------------------------------

  /// Adds a single, already-picked media entry (e.g. from image_picker)
  /// and makes it visible immediately, without requiring a manual
  /// [load] round-trip. Mirrors the upsert behaviour of
  /// [MediaRepository.createMedia] so a future Firebase-backed
  /// repository can replace [HiveMediaRepository] here without any UI
  /// changes.
  Future<MediaModel> addMedia(MediaModel media) async {
    try {
      final created = await _repo.createMedia(media);
      final idx = _allMedia.indexWhere((m) => m.id == created.id);
      if (idx == -1) {
        _allMedia.add(created);
      } else {
        _allMedia[idx] = created;
      }
      notifyListeners();
      await _adjustAlbumPhotoCount(created.albumId, 1);
      return created;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // ---------------------------------------------------------------------
  // Photo editor (Task 21) — API-aware save/overwrite/revert.
  //
  // Unlike [addMedia] (which goes through [MediaRepository.createMedia],
  // unsupported for API-backed media), these three go through
  // [MediaRepository.updateMedia]/[uploadMedia]/[replaceMediaFile]/
  // [revertMedia] directly, so the photo editor's Save/Save as Copy/
  // Overwrite Original/Revert actions actually reach the server for
  // network media instead of silently only touching the local Hive
  // store.
  // ---------------------------------------------------------------------

  /// Non-destructive Save: persists [recipe] as [media]'s edit recipe.
  Future<MediaModel> saveEditRecipe({
    required MediaModel media,
    required EditRecipe recipe,
  }) async {
    final updated = media.copyWith(
      editRecipe: recipe,
      modifiedAt: DateTime.now(),
    );
    final result = await _repo.updateMedia(updated);
    final idx = _allMedia.indexWhere((m) => m.id == result.id);
    if (idx != -1) _allMedia[idx] = result;
    notifyListeners();
    return result;
  }

  /// Save as Copy: uploads the rendered bytes as a brand-new media item
  /// in the same album/folder as [source], carrying [recipe] forward
  /// onto the copy so it stays editable non-destructively too.
  Future<MediaModel> saveEditedCopy({
    required MediaModel source,
    required List<int> bytes,
    required String fileName,
    required String contentType,
    required EditRecipe recipe,
  }) async {
    final uploaded = await _repo.uploadMedia(
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      albumId: source.albumId,
      folderId: source.folderId,
    );
    final result = await _repo.updateMedia(
      uploaded.copyWith(editRecipe: recipe, isFavorite: source.isFavorite),
    );
    _allMedia.add(result);
    notifyListeners();
    await _adjustAlbumPhotoCount(result.albumId, 1);
    return result;
  }

  /// Overwrite Original: destructively replaces [media]'s original file
  /// with the rendered bytes. The backend clears the edit recipe as
  /// part of this (it's now baked into the file) and marks the item as
  /// revertible.
  Future<MediaModel> overwriteMediaFile({
    required MediaModel media,
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) async {
    final result = await _repo.replaceMediaFile(
      id: media.id,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );
    final idx = _allMedia.indexWhere((m) => m.id == result.id);
    if (idx != -1) _allMedia[idx] = result;
    notifyListeners();
    return result;
  }

  /// Revert to Original: undoes a previous [overwriteMediaFile] and
  /// clears any pending edit recipe. Throws if [media] was never
  /// overwritten — check [MediaModel.canRevert] first.
  Future<MediaModel> revertMediaEdits(MediaModel media) async {
    final result = await _repo.revertMedia(media.id);
    final idx = _allMedia.indexWhere((m) => m.id == result.id);
    if (idx != -1) _allMedia[idx] = result;
    notifyListeners();
    return result;
  }

  Future<void> batchDelete() async {
    final ids = _selectedIds.toList(growable: false);
    if (ids.isEmpty) return;

    for (final id in ids) {
      final idx = _allMedia.indexWhere((m) => m.id == id);
      final albumId = idx == -1 ? null : _allMedia[idx].albumId;

      await _repo.deleteMedia(id);
      _allMedia.removeWhere((m) => m.id == id);

      await _adjustAlbumPhotoCount(albumId, -1);
    }
    clearSelection();
    notifyListeners();
  }

  /// Restores previously soft-deleted items.
  ///
  /// This is used by the UI Undo snackbar for delete.
  Future<void> restoreDeletedMedia(List<MediaModel> backup) async {
    if (backup.isEmpty) return;

    for (final m in backup) {
      final restored = m.copyWith(
        isDeleted: false,
        modifiedAt: DateTime.now(),
      );
      await _repo.updateMedia(restored);

      final idx = _allMedia.indexWhere((x) => x.id == m.id);
      if (idx == -1) {
        _allMedia.add(restored);
      } else {
        _allMedia[idx] = restored;
      }

      await _adjustAlbumPhotoCount(restored.albumId, 1);
    }

    // Ensure selection doesn't remain from the delete action.
    clearSelection();
    notifyListeners();
  }

  /// Renames a media item by id while preserving its extension.
  ///
  /// This is UI-driven (Phase 4 Selection Experience) and keeps business
  /// logic inside the controller.
  Future<void> renameMediaById({
    required String mediaId,
    required String newFileName,
  }) async {
    final desired = newFileName.trim();
    if (desired.isEmpty) return;

    // Preserve extension unless the caller already provided one.
    // We interpret "newFileName" as either:
    // - full name with extension, OR
    // - base name (extension will be preserved).
    final idx = _allMedia.indexWhere((m) => m.id == mediaId);
    if (idx == -1) return;

    final current = _allMedia[idx];
    final dot = desired.lastIndexOf('.');
    final hasExt = dot > 0 && dot != desired.length - 1;

    final extension = _extensionOf(current.fileName);
    final finalName = hasExt ? desired : '$desired$extension';

    // Reject whitespace-only or unchanged renames.
    if (finalName.trim().isEmpty) return;
    if (finalName == current.fileName) return;

    // Validate file name (basic): no path separators.
    if (finalName.contains('/') || finalName.contains('\\')) return;

    // Duplicate check within destination scope (albumId/folderId).
    final existingNames = _allMedia
        .where((m) => !m.isDeleted)
        .where((m) => m.id != mediaId)
        .where((m) =>
            m.albumId == current.albumId && m.folderId == current.folderId)
        .map((m) => m.fileName)
        .toSet();

    if (existingNames.contains(finalName)) return;

    final updated = current.copyWith(
      fileName: finalName,
      modifiedAt: DateTime.now(),
    );

    await _repo.updateMedia(updated);

    _allMedia[idx] = updated;
    notifyListeners();
  }

  String _extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot);
  }

  Future<void> batchFavorite({bool? favorite}) async {
    final ids = _selectedIds.toList(growable: false);
    if (ids.isEmpty) return;

    for (final id in ids) {
      // repository only supports toggle, so compute required toggle.
      final idx = _allMedia.indexWhere((m) => m.id == id);
      if (idx == -1) continue;
      final current = _allMedia[idx];

      final shouldBe = favorite ?? !current.isFavorite;
      if (current.isFavorite == shouldBe) continue;

      await _repo.toggleFavorite(id);
      _allMedia[idx] = _allMedia[idx].copyWith(
        isFavorite: shouldBe,
        modifiedAt: DateTime.now(),
      );
    }
    clearSelection();
    notifyListeners();
  }

  Future<void> batchMove({
    required String destinationAlbumId,
    required String? destinationFolderId,
    void Function(int processed, int total)? onProgress,
  }) async {
    final ids = _selectedIds.toList(growable: false);
    if (ids.isEmpty) return;

    final total = ids.length;
    var processed = 0;

    for (final id in ids) {
      final idx = _allMedia.indexWhere((m) => m.id == id);
      final sourceAlbumId = idx == -1 ? null : _allMedia[idx].albumId;

      await _repo.moveMedia(
        id: id,
        albumId: destinationAlbumId,
        folderId: destinationFolderId,
      );
      if (idx != -1) {
        _allMedia[idx] = _allMedia[idx].copyWith(
          albumId: destinationAlbumId,
          folderId: destinationFolderId,
          modifiedAt: DateTime.now(),
        );
      }

      if (sourceAlbumId != destinationAlbumId) {
        await _adjustAlbumPhotoCount(sourceAlbumId, -1);
        await _adjustAlbumPhotoCount(destinationAlbumId, 1);
      }

      processed++;
      onProgress?.call(processed, total);
    }

    clearSelection();
    notifyListeners();
  }

  Future<void> batchCopy(
      {required String destinationAlbumId,
      required String? destinationFolderId,
      void Function(int processed, int total)? onProgress}) async {
    final ids = _selectedIds.toList(growable: false);
    if (ids.isEmpty) return;

    final total = ids.length;
    var processed = 0;

    for (final id in ids) {
      final copied = await _repo.copyMedia(
          id: id, albumId: destinationAlbumId, folderId: destinationFolderId);
      _allMedia.add(copied);

      await _adjustAlbumPhotoCount(copied.albumId, 1);

      processed++;
      onProgress?.call(processed, total);
    }

    clearSelection();
    notifyListeners();
  }

  // Backwards compatible alias (Phase 4 Part 1 may have referenced this)
  Future<void> deleteSelected() => batchDelete();
}

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  // API-backed repository wrapped with a Hive offline read cache (Task
  // 19.13): every successful fetch mirrors into Hive, and fetches fall
  // back to that cache, read-only, when there's no connection. See
  // CachingMediaRepository's doc comment for exactly what is/isn't
  // cached.
  final repo = CachingMediaRepository(
    api: ApiMediaRepository(apiClient: ref.watch(apiClientProvider)),
  );

  // Task 19.14 — keep that Hive cache scoped to whichever user is
  // currently signed in, so switching (or signing out of) accounts on
  // the same device never leaves one account's cached media readable
  // to another. This repository instance is long-lived (only rebuilt
  // if apiClientProvider changes), so we react to auth changes here via
  // ref.listen rather than re-creating the repository on every login.
  ref.listen<AuthState>(authStateProvider, (previous, next) {
    final userId = next.user?.id;
    if (userId != null) {
      // Covers: fresh login, a restored session resolving on cold
      // start, and switching accounts without an intervening logout
      // (scopeCacheToUser itself wipes the previous user's entry when
      // the incoming id differs from the last-cached one).
      // ignore: unawaited_futures
      repo.scopeCacheToUser(userId);
    } else if (previous?.user != null) {
      // A real logout (had a user, now don't) — not the transient
      // "still restoring session" state during app startup, which also
      // has `user == null` but no previous value to compare against.
      // ignore: unawaited_futures
      repo.clearCacheForLogout();
    }
  }, fireImmediately: true);

  return repo;
});

/// Global media controller.
///
/// UI screens will set type/album/folder/search/sort/filter before rendering.
final mediaProvider = ChangeNotifierProvider<MediaListController>((ref) {
  final repo = ref.watch(mediaRepositoryProvider);
  final controller = MediaListController(repository: repo, ref: ref);
  // Deferred to a microtask — see albumProvider for why.
  Future.microtask(controller.load);
  return controller;
});
