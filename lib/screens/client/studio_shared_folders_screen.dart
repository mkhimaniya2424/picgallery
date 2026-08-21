import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../models/folder_model.dart';
import '../../models/album_model.dart';
import '../../providers/client_gallery_provider.dart';
import '../../widgets/client/home_sections.dart' show GalleryGrid;
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/empty_state_card.dart';
import '../../widgets/common/folder_tile.dart';
import '../../widgets/common/inline_error_banner.dart';
import '../../widgets/common/loading_widget.dart';

/// Read-only browse screen for one studio's Shared Gallery — reached
/// from [SharedStudiosScreen] (studio tap, [folderId] null) and pushed
/// onto itself for sub-folder drill-down (same recursive-push pattern
/// as the admin [FolderDetailsScreen]/[FolderListScreen]), sourced
/// entirely from [clientGalleryProvider] instead of
/// `folderProvider`/`albumProvider`.
///
/// Deliberately has none of [FolderDetailsScreen]'s owner actions
/// (rename/move/settings/add media) — a client can only look, never
/// edit, so this screen is just breadcrumb-free navigation plus two
/// read-only sections: sub-folders and shared albums. Reuses
/// [FolderTile] and [GalleryGrid] as-is so the visuals match the rest
/// of the app exactly (Task 15 covers making the album grid's tap
/// target, [AlbumDetailsScreen], resolve albums sourced this way).
class StudioSharedFoldersScreen extends ConsumerStatefulWidget {
  final String studioId;

  /// Null means the studio's root level (albums/folders shared with no
  /// folder). Non-null drills into that folder within [studioId].
  final String? folderId;

  const StudioSharedFoldersScreen({super.key, required this.studioId, this.folderId});

  @override
  ConsumerState<StudioSharedFoldersScreen> createState() => _StudioSharedFoldersScreenState();
}

class _StudioSharedFoldersScreenState extends ConsumerState<StudioSharedFoldersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
  }

  /// Loads whatever [clientGalleryProvider] doesn't already have scoped
  /// to this exact (studio, folder) pair. Cheap to call on every push —
  /// each branch is a no-op once the notifier is already there, so
  /// navigating back and forth between folders doesn't re-fetch
  /// anything unnecessarily.
  Future<void> _ensureLoaded() async {
    final notifier = ref.read(clientGalleryProvider.notifier);
    final current = ref.read(clientGalleryProvider);

    if (current.selectedStudioId != widget.studioId) {
      // Fresh entry into this studio (from SharedStudiosScreen, or a
      // deep link) — loads folders + root albums together.
      await notifier.selectStudio(widget.studioId);
      if (widget.folderId != null) {
        await notifier.selectFolder(widget.folderId);
      }
    } else if (current.selectedFolderId != widget.folderId) {
      // Already browsing this studio — just drilling into a different
      // folder within it.
      await notifier.selectFolder(widget.folderId);
    }
  }

  void _openFolder(String folderId) {
    Navigator.of(context).pushNamed(
      AppRoutes.studioSharedFolders,
      arguments: {'studioId': widget.studioId, 'folderId': folderId},
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clientGalleryProvider);
    final isCurrent = state.selectedStudioId == widget.studioId;

    final title = isCurrent
        ? (widget.folderId == null
            ? (state.selectedStudio?.name ?? 'Shared Gallery')
            : _folderName(state.folders, widget.folderId!))
        : 'Shared Gallery';

    return Scaffold(
      
      appBar: CustomAppBar(title: title, showBack: true),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _ensureLoaded,
          child: _buildBody(state, isCurrent),
        ),
      ),
    );
  }

  String _folderName(List<FolderModel> folders, String folderId) {
    for (final f in folders) {
      if (f.id == folderId) return f.name;
    }
    return 'Folder';
  }

  Widget _buildBody(ClientGalleryState state, bool isCurrent) {
    final loadingFolders = !isCurrent || state.isLoadingFolders;
    final loadingAlbums = !isCurrent || state.isLoadingAlbums;

    if (loadingFolders && loadingAlbums) {
      return _scrollableMessage(
        const Center(child: LoadingWidget(message: 'Loading shared gallery…')),
      );
    }

    final error = isCurrent ? (state.foldersError ?? state.albumsError) : null;
    final subfolders =
        isCurrent ? state.folders.where((f) => f.parentId == widget.folderId).toList() : <FolderModel>[];
    final albums = isCurrent ? state.albums : const <AlbumModel>[];

    if (error != null && subfolders.isEmpty && albums.isEmpty) {
      return _scrollableMessage(
        Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: InlineErrorBanner(message: error),
          ),
        ),
      );
    }

    if (subfolders.isEmpty && albums.isEmpty && !loadingFolders && !loadingAlbums) {
      return _scrollableMessage(_buildEmptyState());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      children: [
        if (subfolders.isNotEmpty) ...[
          const Text(
            'Folders',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...subfolders.map((folder) {
            final childCount = state.folders.where((f) => f.parentId == folder.id).length;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: FolderTile(
                folder: folder,
                childFolderCount: childCount,
                onTap: () => _openFolder(folder.id),
              ),
            );
          }),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (loadingAlbums && albums.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(child: LoadingWidget(message: 'Loading albums…')),
          )
        else if (albums.isNotEmpty) ...[
          const Text(
            'Shared Albums',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text),
          ),
          const SizedBox(height: AppSpacing.sm),
          GalleryGrid(
            albums: albums,
            maxItems: albums.length,
            sharedStudioId: widget.studioId,
          ),
        ],
      ],
    );
  }

  /// Wraps non-list states (loading/error/empty) in a scrollable so
  /// [RefreshIndicator] still works with nothing to scroll — same
  /// convention as [SharedStudiosScreen]/[FavoriteStudiosScreen].
  Widget _scrollableMessage(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            EmptyStateCard(
              icon: Icons.folder_off_rounded,
              message: 'Nothing Shared Here Yet',
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              'This folder has no shared albums or sub-folders right now.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.subtitle,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}