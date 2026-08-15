import '../core/utils/app_exceptions.dart';
import '../models/media_model.dart';
import 'media_repository.dart';

/// In-memory [MediaRepository].
///
/// Mirrors [HiveMediaRepository]'s behavior (soft-delete filtering,
/// filename collision handling on copy) but keeps everything in a
/// plain in-memory list instead of Hive.
///
/// IMPORTANT:
/// - No dummy/seed content.
/// - File operations (copy/move bytes) are NOT performed here; we only
///   update metadata, same as the Hive-backed implementation.
/// - No persistence across restarts — data is lost when the app/process
///   ends. This is expected and fine for an in-memory repository.
class InMemoryMediaRepository implements MediaRepository {
  final List<MediaModel> _items = [];

  (String base, String ext) _nameAndExt(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0 || dot == fileName.length - 1) {
      return (fileName, '');
    }
    return (fileName.substring(0, dot), fileName.substring(dot));
  }

  String _uniqueFileName({
    required String desiredName,
    required Set<String> existingNames,
  }) {
    final (base, ext) = _nameAndExt(desiredName);

    if (!existingNames.contains(desiredName)) return desiredName;

    var i = 1;
    while (true) {
      final candidate = '$base ($i)$ext';
      if (!existingNames.contains(candidate)) return candidate;
      i++;
    }
  }

  Future<List<MediaModel>> _loadAll() async {
    // Keep soft-deleted items in the list but don't return them by default.
    return _items;
  }

  Future<void> _saveAll(List<MediaModel> media) async {
    _items
      ..clear()
      ..addAll(media);
  }

  @override
  Future<List<MediaModel>> fetchMedia({
    String? albumId,
    String? folderId,
    bool unfiledOnly = false,
    MediaType? type,
    bool favoritesOnly = false,
  }) async {
    final media = await _loadAll();
    return media.where((m) {
      if (m.isDeleted) return false;
      if (albumId != null && m.albumId != albumId) return false;
      if (folderId != null && m.folderId != folderId) return false;
      if (unfiledOnly && m.albumId != null) return false;
      if (type != null && m.type != type) return false;
      if (favoritesOnly && !m.isFavorite) return false;
      return true;
    }).toList(growable: false);
  }

  @override
  Future<MediaModel> createMedia(MediaModel media) async {
    final all = await _loadAll();
    final idx = all.indexWhere((m) => m.id == media.id);
    final now = DateTime.now();

    final toSave = media.copyWith(
      createdAt: media.createdAt == DateTime.fromMillisecondsSinceEpoch(0)
          ? now
          : media.createdAt,
      modifiedAt: now,
    );

    if (idx == -1) {
      all.add(toSave);
    } else {
      // Treat as upsert.
      all[idx] = toSave;
    }

    await _saveAll(all);
    return toSave;
  }

  @override
  Future<MediaModel> updateMedia(MediaModel media) async {
    final all = await _loadAll();
    final idx = all.indexWhere((m) => m.id == media.id);
    if (idx == -1) {
      throw NotFoundException('Media "${media.id}" no longer exists');
    }

    final now = DateTime.now();
    final toSave = media.copyWith(modifiedAt: now);
    all[idx] = toSave;
    await _saveAll(all);
    return toSave;
  }

  @override
  Future<void> deleteMedia(String id) async {
    final all = await _loadAll();
    final idx = all.indexWhere((m) => m.id == id);
    if (idx == -1) throw NotFoundException('Media "$id" no longer exists');

    // Soft delete.
    all[idx] = all[idx].copyWith(isDeleted: true, modifiedAt: DateTime.now());
    await _saveAll(all);
  }

  @override
  Future<void> moveMedia({
    required String id,
    String? albumId,
    String? folderId,
  }) async {
    final all = await _loadAll();
    final idx = all.indexWhere((m) => m.id == id);
    if (idx == -1) throw NotFoundException('Media "$id" no longer exists');

    final updated = all[idx].copyWith(
      albumId: albumId,
      folderId: folderId,
      modifiedAt: DateTime.now(),
    );
    all[idx] = updated;
    await _saveAll(all);
  }

  @override
  Future<MediaModel> copyMedia({
    required String id,
    String? albumId,
    String? folderId,
    DuplicateResolution duplicateResolution = DuplicateResolution.autoRename,
  }) async {
    final all = await _loadAll();
    final idx = all.indexWhere((m) => m.id == id);
    if (idx == -1) throw NotFoundException('Media "$id" no longer exists');

    final source = all[idx];
    final now = DateTime.now();

    // Detect duplicates in the destination album/folder.
    // Since Phase 4 moves/copies are driven by destination albums,
    // this set is the correct scope.
    final existingNames = all
        .where((m) => !m.isDeleted)
        .where((m) => m.albumId == albumId && m.folderId == folderId)
        .map((m) => m.fileName)
        .toSet();

    final String destinationName;
    final bool isDuplicate = existingNames.contains(source.fileName);

    if (isDuplicate && duplicateResolution == DuplicateResolution.skip) {
      // Signal "skipped" by returning the source unchanged.
      // Caller must interpret this via name equality + id difference check.
      return Future.value(source);
    }

    // Default behavior: auto-rename duplicates.
    destinationName = _uniqueFileName(
      desiredName: source.fileName,
      existingNames: existingNames,
    );

    final copied = source.copyWith(
      id: 'me-${now.microsecondsSinceEpoch}',
      albumId: albumId,
      folderId: folderId,
      fileName: destinationName,
      createdAt: now,
      modifiedAt: now,
      isDeleted: false,
    );

    all.add(copied);
    await _saveAll(all);
    return copied;
  }

  @override
  Future<void> toggleFavorite(String id) async {
    final all = await _loadAll();
    final idx = all.indexWhere((m) => m.id == id);
    if (idx == -1) throw NotFoundException('Media "$id" no longer exists');

    final updated = all[idx].copyWith(
      isFavorite: !all[idx].isFavorite,
      modifiedAt: DateTime.now(),
    );
    all[idx] = updated;
    await _saveAll(all);
  }

  @override
  Future<List<MediaModel>> fetchDeletedMedia() async {
    final media = await _loadAll();
    return media.where((m) => m.isDeleted).toList(growable: false);
  }

  @override
  Future<void> permanentlyDeleteMedia(String id) async {
    final all = await _loadAll();
    all.removeWhere((m) => m.id == id);
    await _saveAll(all);
  }

  @override
  Future<void> emptyTrash() async {
    final all = await _loadAll();
    all.removeWhere((m) => m.isDeleted);
    await _saveAll(all);
  }

  @override
  Future<MediaModel> uploadMedia({
    required List<int> bytes,
    required String fileName,
    required String contentType,
    String? albumId,
    String? folderId,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    // In-memory mock: report progress 100%
    onSendProgress?.call(bytes.length, bytes.length);
    final now = DateTime.now();
    final media = MediaModel(
      id: 'mem-${now.microsecondsSinceEpoch}',
      type: contentType.startsWith('video/') ? MediaType.video : MediaType.photo,
      filePath: '',
      thumbnailPath: '',
      fileName: fileName,
      albumId: albumId,
      folderId: folderId,
      size: bytes.length,
      width: 0,
      height: 0,
      createdAt: now,
      modifiedAt: now,
    );
    return createMedia(media);
  }

  @override
  Future<MediaModel> replaceMediaFile({
    required String id,
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) async {
    final all = await _loadAll();
    final idx = all.indexWhere((m) => m.id == id);
    if (idx == -1) {
      throw NotFoundException('Media "$id" no longer exists');
    }
    final now = DateTime.now();
    final updated = all[idx].copyWith(
      size: bytes.length,
      modifiedAt: now,
      canRevert: true,
      editRecipe: null,
    );
    all[idx] = updated;
    await _saveAll(all);
    return updated;
  }

  @override
  Future<MediaModel> revertMedia(String id) async {
    final all = await _loadAll();
    final idx = all.indexWhere((m) => m.id == id);
    if (idx == -1) {
      throw NotFoundException('Media "$id" no longer exists');
    }
    if (!all[idx].canRevert) {
      throw StateError('Nothing to revert — this media was never overwritten');
    }
    final updated = all[idx].copyWith(
      canRevert: false,
      editRecipe: null,
      modifiedAt: DateTime.now(),
    );
    all[idx] = updated;
    await _saveAll(all);
    return updated;
  }
}
