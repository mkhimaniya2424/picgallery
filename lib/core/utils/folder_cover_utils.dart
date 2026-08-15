import '../../models/album_model.dart';
import '../../models/media_model.dart';

/// Picks a representative cover photo for a folder, checked in order:
/// 1. Media uploaded directly into the folder (`MediaModel.folderId`).
/// 2. Media inside an album that's filed under the folder
///    (`AlbumModel.folderId` → `MediaModel.albumId`).
/// Returns null when the folder (and its albums) have no media yet, so
/// callers fall back to the gradient placeholder.
MediaModel? coverForFolder({
  required String folderId,
  required List<MediaModel> allMedia,
  required List<AlbumModel> allAlbums,
}) {
  final direct = allMedia.where((m) => !m.isDeleted && m.folderId == folderId);
  for (final m in direct) {
    if (m.type == MediaType.photo) return m;
  }
  if (direct.isNotEmpty) return direct.first;

  final albumIds = allAlbums
      .where((a) => a.folderId == folderId)
      .map((a) => a.id)
      .toSet();
  if (albumIds.isEmpty) return null;

  final viaAlbums =
      allMedia.where((m) => !m.isDeleted && albumIds.contains(m.albumId));
  for (final m in viaAlbums) {
    if (m.type == MediaType.photo) return m;
  }
  return viaAlbums.isNotEmpty ? viaAlbums.first : null;
}
