import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/subscription_guard.dart';
import '../../models/album_model.dart';
import '../../models/folder_model.dart';
import '../../providers/album_provider.dart';
import '../../providers/folder_provider.dart';

import '../../widgets/common/custom_app_bar.dart';

import '../../widgets/common/empty_state_card.dart';
import '../../widgets/common/loading_widget.dart';

import 'widgets/album_card.dart';

class AlbumsListScreen extends ConsumerStatefulWidget {
  const AlbumsListScreen({super.key});

  @override
  ConsumerState<AlbumsListScreen> createState() => _AlbumsListScreenState();
}

class _AlbumsListScreenState extends ConsumerState<AlbumsListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Keep initial in sync.
    final c = ref.read(albumProvider);
    _searchController.text = c.searchQuery;
  }

  Future<void> _confirmDeleteAlbum(AlbumModel album) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Album?'),
        content: Text(
            'This will permanently remove "${album.name}" and its ${album.photoCount} photos. This can\'t be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(albumProvider).deleteAlbum(album.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${album.name}" deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _moveAlbum(AlbumModel album, List<FolderModel> folders) async {
    final result = await showModalBottomSheet<Object?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
              child: Text('Move to folder', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded, color: AppColors.subtitle),
              title: const Text('No folder (unfile)'),
              trailing:
                  album.folderId == null ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
              onTap: () => Navigator.of(ctx).pop(_unfileSentinel),
            ),
            const Divider(height: 1),
            ...folders.map(
              (f) => ListTile(
                leading: const Icon(Icons.folder_rounded, color: AppColors.primary),
                title: Text(f.name),
                trailing:
                    album.folderId == f.id ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                onTap: () => Navigator.of(ctx).pop(f.id),
              ),
            ),
          ],
        ),
      ),
    );

    if (result == null || !mounted) return;
    final newFolderId = identical(result, _unfileSentinel) ? null : result as String;
    if (newFolderId == album.folderId) return;

    try {
      await ref.read(albumProvider).moveToFolder(album.id, newFolderId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newFolderId == null ? 'Album unfiled' : 'Album moved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final albumState = ref.watch(albumProvider);
    final folderState = ref.watch(folderProvider);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Albums',
        showBack: false,
        actions: [
          IconButton(
            tooltip: 'Manage Collections',
            icon: const Icon(Icons.collections_bookmark_rounded),
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.collections);
            },
          ),
          IconButton(
            tooltip: 'Manage Folders',
            icon: const Icon(Icons.folder_rounded),
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.adminFolderList);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'albums_list_fab',
        onPressed: () {
          requireActiveSubscription(context, ref, () {
            Navigator.of(context).pushNamed(AppRoutes.adminAlbumCreate);
          });
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create Album'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(albumProvider).load(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Controls
                  Builder(
                    builder: (context) {
                      // simple inline controls without additional widget dependency
                      return Column(
                        children: [
                          TextField(
                            controller: _searchController,
                            onChanged: (v) {
                              albumState.setSearchQuery(v);
                            },
                            decoration: InputDecoration(
                              hintText: 'Search albums…',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded),
                                      onPressed: () {
                                        _searchController.clear();
                                        albumState.setSearchQuery('');
                                      },
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<AlbumSortOption>(
                                  initialValue: albumState.sortOption,
                                  items: const [
                                    DropdownMenuItem(
                                        value: AlbumSortOption.recent,
                                        child: Text('Recent')),
                                    DropdownMenuItem(
                                        value: AlbumSortOption.name,
                                        child: Text('Name')),
                                    DropdownMenuItem(
                                        value: AlbumSortOption.photoCount,
                                        child: Text('Photo count')),
                                    DropdownMenuItem(
                                        value: AlbumSortOption.folderCount,
                                        child: Text('Folder count')),
                                  ],
                                  onChanged: (v) {
                                    if (v == null) return;
                                    albumState.setSortOption(v);
                                  },
                                  decoration:
                                      const InputDecoration(labelText: 'Sort'),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              IconButton.filledTonal(
                                tooltip: albumState.isGrid ? 'Switch to list view' : 'Switch to grid view',
                                onPressed: albumState.toggleGridList,
                                icon: Icon(albumState.isGrid
                                    ? Icons.grid_view_rounded
                                    : Icons.view_list_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Expanded(
                                child: folderState.isLoading
                                    ? const SizedBox.shrink()
                                    : DropdownButtonFormField<String?>(
                                        initialValue: albumState.folderId,
                                        items: [
                                          const DropdownMenuItem<String?>(
                                            value: null,
                                            child: Text('All folders'),
                                          ),
                                          ...folderState.folders.map(
                                              (f) => DropdownMenuItem<String?>(
                                                    value: f.id,
                                                    child: Text(f.name),
                                                  )),
                                        ],
                                        onChanged: albumState.setFolder,
                                        decoration: const InputDecoration(
                                          labelText: 'Filter folder',
                                        ),
                                      ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              FilterChip(
                                label: const Text('Favorites'),
                                selected: albumState.filterOption ==
                                    AlbumFilterOption.favorites,
                                onSelected: (v) {
                                  albumState.setFilterOption(v
                                      ? AlbumFilterOption.favorites
                                      : AlbumFilterOption.all);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                      );
                    },
                  ),

                  if (albumState.isLoading || folderState.isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                      child: Center(child: LoadingWidget(message: 'Loading albums…')),
                    )
                  else if (albumState.lastError != null && albumState.lastError!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                      child: Center(
                        child: EmptyStateCard(
                          icon: Icons.error_outline_rounded,
                          message: albumState.lastError!.trim(),
                        ),
                      ),
                    )
                  else if (albumState.filteredAlbums.isEmpty)
                    const Center(
                      child: EmptyStateCard(
                        icon: Icons.photo_library_outlined,
                        message: 'No albums found. Try adjusting filters/search.',
                      ),
                    )
                  else if (albumState.isGrid)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: albumState.filteredAlbums.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: AppSpacing.md,
                        crossAxisSpacing: AppSpacing.md,
                        childAspectRatio: 0.68,
                      ),
                      itemBuilder: (context, i) {
                        final album = albumState.filteredAlbums[i];
                        return _AnimatedAlbumTile(
                          index: i,
                          child: AlbumCard(
                            album: album,
                            onToggleFavorite: () => albumState.toggleFavorite(album.id),
                            onTap: () => Navigator.of(context).pushNamed(
                              AppRoutes.adminAlbumDetails,
                              arguments: album.id,
                            ),
                            onEdit: () => Navigator.of(context).pushNamed(
                              AppRoutes.adminAlbumEdit,
                              arguments: album.id,
                            ),
                            onMove: () => _moveAlbum(album, folderState.folders),
                            onDelete: () => _confirmDeleteAlbum(album),
                          ),
                        );
                      },
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: albumState.filteredAlbums.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) {
                        final album = albumState.filteredAlbums[i];
                        return _AnimatedAlbumTile(
                          index: i,
                          child: AlbumCard(
                            album: album,
                            onToggleFavorite: () => albumState.toggleFavorite(album.id),
                            onTap: () => Navigator.of(context).pushNamed(
                              AppRoutes.adminAlbumDetails,
                              arguments: album.id,
                            ),
                            onEdit: () => Navigator.of(context).pushNamed(
                              AppRoutes.adminAlbumEdit,
                              arguments: album.id,
                            ),
                            onMove: () => _moveAlbum(album, folderState.folders),
                            onDelete: () => _confirmDeleteAlbum(album),
                            compact: true,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Distinguishes "user picked No folder" from "sheet dismissed with no
/// selection" in [_AlbumsListScreenState._moveAlbum].
const Object _unfileSentinel = _UnfileSentinelToken();

class _UnfileSentinelToken {
  const _UnfileSentinelToken();
}

/// Light staggered fade+rise entrance so newly-loaded/created albums
/// don't just pop onto the grid — each tile's delay is capped so a long
/// list doesn't feel sluggish to finish animating in.
class _AnimatedAlbumTile extends StatefulWidget {
  const _AnimatedAlbumTile({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_AnimatedAlbumTile> createState() => _AnimatedAlbumTileState();
}

class _AnimatedAlbumTileState extends State<_AnimatedAlbumTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.medium,
  );
  late final Animation<double> _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    final delayMs = (widget.index.clamp(0, 8)) * 40;
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}