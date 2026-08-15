import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/album_model.dart';
import '../models/folder_model.dart';
import '../repositories/client_gallery_repository.dart';
import 'auth_providers.dart';

// ─── Repository provider ────────────────────────────────────────────────────

/// Singleton repository that talks to the three (now four, with album media)
/// `/client/…` endpoints. Swap out [ApiClientGalleryRepository] here for a
/// mock in tests — nothing else needs to change.
final clientGalleryRepositoryProvider = Provider<ClientGalleryRepository>((ref) {
  return ApiClientGalleryRepository(apiClient: ref.watch(apiClientProvider));
});

// ─── State ──────────────────────────────────────────────────────────────────

/// Holds everything the client-side Shared Gallery needs: the flat list of
/// studios (for [SharedStudiosScreen]) plus the currently-selected studio's
/// folders and albums (for [StudioSharedFoldersScreen]).
///
/// Deliberately **separate** from [albumProvider] / [folderProvider] — those
/// only ever hold the studio owner's local data. Mixing them would either
/// pollute the studio UI or leak client-only filtering through to it.
class ClientGalleryState {
  final List<SharedStudioModel> studios;
  final bool isLoadingStudios;
  final String? studiosError;

  /// The studio the client is currently browsing (`null` on first open).
  final String? selectedStudioId;
  final SharedStudioModel? selectedStudio;

  final List<FolderModel> folders;
  final bool isLoadingFolders;
  final String? foldersError;

  /// Which folder the client is currently in (`null` = studio root).
  final String? selectedFolderId;

  final List<AlbumModel> albums;
  final bool isLoadingAlbums;
  final String? albumsError;

  const ClientGalleryState({
    this.studios = const [],
    this.isLoadingStudios = false,
    this.studiosError,
    this.selectedStudioId,
    this.selectedStudio,
    this.folders = const [],
    this.isLoadingFolders = false,
    this.foldersError,
    this.selectedFolderId,
    this.albums = const [],
    this.isLoadingAlbums = false,
    this.albumsError,
  });

  ClientGalleryState copyWith({
    List<SharedStudioModel>? studios,
    bool? isLoadingStudios,
    String? studiosError,
    bool clearStudiosError = false,
    String? selectedStudioId,
    bool clearSelectedStudio = false,
    SharedStudioModel? selectedStudio,
    List<FolderModel>? folders,
    bool? isLoadingFolders,
    String? foldersError,
    bool clearFoldersError = false,
    String? selectedFolderId,
    bool clearSelectedFolder = false,
    List<AlbumModel>? albums,
    bool? isLoadingAlbums,
    String? albumsError,
    bool clearAlbumsError = false,
  }) {
    return ClientGalleryState(
      studios: studios ?? this.studios,
      isLoadingStudios: isLoadingStudios ?? this.isLoadingStudios,
      studiosError: clearStudiosError ? null : (studiosError ?? this.studiosError),
      selectedStudioId:
          clearSelectedStudio ? null : (selectedStudioId ?? this.selectedStudioId),
      selectedStudio: clearSelectedStudio ? null : (selectedStudio ?? this.selectedStudio),
      folders: folders ?? this.folders,
      isLoadingFolders: isLoadingFolders ?? this.isLoadingFolders,
      foldersError: clearFoldersError ? null : (foldersError ?? this.foldersError),
      selectedFolderId:
          clearSelectedFolder ? null : (selectedFolderId ?? this.selectedFolderId),
      albums: albums ?? this.albums,
      isLoadingAlbums: isLoadingAlbums ?? this.isLoadingAlbums,
      albumsError: clearAlbumsError ? null : (albumsError ?? this.albumsError),
    );
  }
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class ClientGalleryNotifier extends StateNotifier<ClientGalleryState> {
  ClientGalleryNotifier(this._repo) : super(const ClientGalleryState());

  final ClientGalleryRepository _repo;

  // ── Studio list ─────────────────────────────────────────────────────────

  /// Fetches the shared-studios list. Called once from [SharedGalleriesSection]
  /// / [SharedStudiosScreen] on first render, and on pull-to-refresh.
  Future<void> loadStudios() async {
    if (state.isLoadingStudios) return; // already in flight
    state = state.copyWith(isLoadingStudios: true, clearStudiosError: true);
    try {
      final studios = await _repo.fetchSharedStudios();
      state = state.copyWith(studios: studios, isLoadingStudios: false);
    } catch (e) {
      state = state.copyWith(
        isLoadingStudios: false,
        studiosError: e.toString(),
      );
    }
  }

  // ── Folder + album drill-down ─────────────────────────────────────────

  /// Selects a studio and loads its folders + root albums in parallel.
  /// Resets [selectedFolderId] to null (studio root) whenever the studio
  /// changes so stale folder state never bleeds across studios.
  Future<void> selectStudio(String studioId) async {
    // Look up the studio metadata we already fetched, if available.
    final studio = state.studios.where((s) => s.id == studioId).firstOrNull;

    state = state.copyWith(
      selectedStudioId: studioId,
      selectedStudio: studio,
      folders: [],
      albums: [],
      isLoadingFolders: true,
      isLoadingAlbums: true,
      clearFoldersError: true,
      clearAlbumsError: true,
      clearSelectedFolder: true,
    );

    // Load folders and root albums concurrently.
    await Future.wait([
      _loadFolders(studioId),
      _loadAlbums(studioId, folderId: null),
    ]);
  }

  /// Drills into a sub-folder (or back up to root when [folderId] is null).
  /// Folder list is already loaded from [selectStudio] — only albums are
  /// re-fetched here.
  Future<void> selectFolder(String? folderId) async {
    final studioId = state.selectedStudioId;
    if (studioId == null) return;

    state = state.copyWith(
      selectedFolderId: folderId ?? '',
      clearSelectedFolder: folderId == null,
      albums: [],
      isLoadingAlbums: true,
      clearAlbumsError: true,
    );
    await _loadAlbums(studioId, folderId: folderId);
  }

  // ── Private helpers ───────────────────────────────────────────────────

  Future<void> _loadFolders(String studioId) async {
    try {
      final folders = await _repo.fetchSharedFolders(studioId);
      state = state.copyWith(folders: folders, isLoadingFolders: false);
    } catch (e) {
      state = state.copyWith(
        isLoadingFolders: false,
        foldersError: e.toString(),
      );
    }
  }

  Future<void> _loadAlbums(String studioId, {required String? folderId}) async {
    try {
      final albums = await _repo.fetchSharedAlbums(studioId, folderId: folderId);
      state = state.copyWith(albums: albums, isLoadingAlbums: false);
    } catch (e) {
      state = state.copyWith(
        isLoadingAlbums: false,
        albumsError: e.toString(),
      );
    }
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

/// The main Riverpod entry-point for the client Shared Gallery. Watch this
/// from [SharedGalleriesSection] (studios list on HomeScreen) and
/// [StudioSharedFoldersScreen] (folder drill-down). Call `.notifier` methods
/// to trigger loads.
///
/// Kept separate from [albumProvider] / [folderProvider] so the studio-owner
/// UI is never accidentally contaminated with client-filtered data.
final clientGalleryProvider =
    StateNotifierProvider<ClientGalleryNotifier, ClientGalleryState>((ref) {
  return ClientGalleryNotifier(ref.watch(clientGalleryRepositoryProvider));
});
