import 'album_model.dart';
import 'folder_model.dart';

/// Aggregate numbers for the Albums feature — either across the whole
/// library or scoped to a single folder. Computed on the fly from
/// in-memory data, never persisted.
class AlbumStatistics {
  final int totalAlbums;
  final int totalPhotos;
  final int totalFavorites;
  final double averagePhotosPerAlbum;
  final AlbumModel? mostRecentAlbum;
  final AlbumModel? largestAlbum;
  final int unfiledAlbumCount;

  const AlbumStatistics({
    required this.totalAlbums,
    required this.totalPhotos,
    required this.totalFavorites,
    required this.averagePhotosPerAlbum,
    required this.mostRecentAlbum,
    required this.largestAlbum,
    required this.unfiledAlbumCount,
  });

  static AlbumStatistics fromAlbums(List<AlbumModel> albums) {
    if (albums.isEmpty) {
      return const AlbumStatistics(
        totalAlbums: 0,
        totalPhotos: 0,
        totalFavorites: 0,
        averagePhotosPerAlbum: 0,
        mostRecentAlbum: null,
        largestAlbum: null,
        unfiledAlbumCount: 0,
      );
    }

    final totalPhotos = albums.fold<int>(0, (sum, a) => sum + a.photoCount);
    final totalFavorites = albums.where((a) => a.isFavorite).length;
    final unfiled = albums.where((a) => a.folderId == null).length;

    var mostRecent = albums.first;
    var largest = albums.first;
    for (final a in albums) {
      if (a.updatedAt.isAfter(mostRecent.updatedAt)) mostRecent = a;
      if (a.photoCount > largest.photoCount) largest = a;
    }

    return AlbumStatistics(
      totalAlbums: albums.length,
      totalPhotos: totalPhotos,
      totalFavorites: totalFavorites,
      averagePhotosPerAlbum: totalPhotos / albums.length,
      mostRecentAlbum: mostRecent,
      largestAlbum: largest,
      unfiledAlbumCount: unfiled,
    );
  }
}

/// Aggregate numbers for the Folders feature — total folders, how many
/// sit at the root, how deep the tree goes, and how many albums live
/// under a given folder (including nested sub-folders).
class FolderStatistics {
  final int totalFolders;
  final int rootFolderCount;
  final int hiddenFolderCount;
  final int favoriteFolderCount;
  final int maxDepth;
  final double averageAlbumsPerFolder;

  const FolderStatistics({
    required this.totalFolders,
    required this.rootFolderCount,
    required this.hiddenFolderCount,
    required this.favoriteFolderCount,
    required this.maxDepth,
    required this.averageAlbumsPerFolder,
  });

  static FolderStatistics fromFolders(List<FolderModel> folders) {
    if (folders.isEmpty) {
      return const FolderStatistics(
        totalFolders: 0,
        rootFolderCount: 0,
        hiddenFolderCount: 0,
        favoriteFolderCount: 0,
        maxDepth: 0,
        averageAlbumsPerFolder: 0,
      );
    }

    int depthOf(FolderModel folder) {
      var depth = 1;
      var current = folder;
      final seen = <String>{current.id};
      while (current.parentId != null) {
        FolderModel? parent;
        for (final f in folders) {
          if (f.id == current.parentId) {
            parent = f;
            break;
          }
        }
        if (parent == null || !seen.add(parent.id)) break;
        current = parent;
        depth++;
      }
      return depth;
    }

    final totalAlbums = folders.fold<int>(0, (sum, f) => sum + f.albumCount);
    final maxDepth = folders.map(depthOf).fold<int>(0, (m, d) => d > m ? d : m);

    return FolderStatistics(
      totalFolders: folders.length,
      rootFolderCount: folders.where((f) => f.parentId == null).length,
      hiddenFolderCount: folders.where((f) => f.isHidden).length,
      favoriteFolderCount: folders.where((f) => f.isFavorite).length,
      maxDepth: maxDepth,
      averageAlbumsPerFolder: totalAlbums / folders.length,
    );
  }
}
