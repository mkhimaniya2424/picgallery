import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/album_model.dart';
import '../repositories/client_gallery_repository.dart';
import 'client_gallery_provider.dart';

/// State for the client's cross-studio "connected" gallery view — every
/// album belonging to a studio this client has an *accepted* connection
/// with (`GET /albums/shared-with-me`). Deliberately separate from
/// [ClientGalleryState] (share-based, one studio at a time) and from
/// [albumProvider]/[AlbumState] (studio-owner's own albums, 403s for a
/// client) — mirrors [ClientGalleryNotifier]'s isLoading/error pattern.
class ConnectedAlbumsState {
  final List<AlbumModel> albums;
  final bool isLoading;
  final String? error;

  const ConnectedAlbumsState({
    this.albums = const [],
    this.isLoading = false,
    this.error,
  });

  ConnectedAlbumsState copyWith({
    List<AlbumModel>? albums,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ConnectedAlbumsState(
      albums: albums ?? this.albums,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// Most-recently-updated albums first — backs "Continue browsing" /
  /// "Recently Viewed"-style carousels. Capped at [limit].
  List<AlbumModel> recentAlbums({int limit = 5}) {
    final sorted = [...albums]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted.take(limit).toList(growable: false);
  }

  /// Highest asset-count albums first, empty albums excluded — backs
  /// "Trending"-style carousels. Capped at [limit].
  List<AlbumModel> trendingAlbums({int limit = 5}) {
    final sorted = [...albums]
      ..sort((a, b) =>
          (b.photoCount + b.videoCount).compareTo(a.photoCount + a.videoCount));
    return sorted
        .where((a) => a.photoCount + a.videoCount > 0)
        .take(limit)
        .toList(growable: false);
  }

  /// Albums the owning studio has flagged as a favorite — backs "Saved
  /// Galleries".
  List<AlbumModel> get favoriteAlbums =>
      albums.where((a) => a.isFavorite).toList(growable: false);
}

class ConnectedAlbumsNotifier extends StateNotifier<ConnectedAlbumsState> {
  ConnectedAlbumsNotifier(this._repo) : super(const ConnectedAlbumsState()) {
    load();
  }

  final ClientGalleryRepository _repo;

  Future<void> load() async {
    if (state.isLoading) return; // already in flight
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final albums = await _repo.fetchConnectedAlbums();
      state = state.copyWith(albums: albums, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Re-fetches from the server — e.g. Home's pull-to-refresh.
  Future<void> refresh() => load();
}

/// The main Riverpod entry-point for the client's connection-based
/// gallery view. Watch this from Home's connection-based sections
/// (Continue Viewing, Recently Viewed, Trending, Saved Galleries —
/// "Recommended" was dropped in Task 21.20) instead of the
/// studio-owner [albumProvider], which 403s for a client account.
final connectedAlbumsProvider =
    StateNotifierProvider<ConnectedAlbumsNotifier, ConnectedAlbumsState>((ref) {
  return ConnectedAlbumsNotifier(ref.watch(clientGalleryRepositoryProvider));
});