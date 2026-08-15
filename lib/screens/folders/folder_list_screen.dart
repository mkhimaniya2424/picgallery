import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/folder_cover_utils.dart';
import '../../core/utils/subscription_guard.dart';
import '../../providers/album_provider.dart';
import '../../providers/folder_provider.dart';
import '../../providers/media_provider.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/empty_state_card.dart';
import '../../widgets/common/folder_tile.dart';
import '../../widgets/common/loading_widget.dart';

/// Admin-only Folder List — reached from the Albums List app bar and
/// from Album Details. Lets the studio owner browse, create and drill
/// into folders.
///
/// Shows root-level folders only (`parentId == null`) — tapping one
/// opens [FolderDetailsScreen], which is where its sub-folders live and
/// can be drilled into recursively, so folder-in-folder nesting reads
/// as a normal file-browser hierarchy instead of one long flat list.
class FolderListScreen extends ConsumerWidget {
  const FolderListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folderState = ref.watch(folderProvider);
    final mediaState = ref.watch(mediaProvider);
    final albumState = ref.watch(albumProvider);

    final rootFolders = folderState.folders.where((f) => f.parentId == null).toList();

    return Scaffold(
      appBar: const CustomAppBar(title: 'Folders', showBack: true),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'folder_list_fab',
        onPressed: () {
          requireActiveSubscription(context, ref, () {
            Navigator.of(context).pushNamed(AppRoutes.adminFolderCreate);
          });
        },
        icon: const Icon(Icons.create_new_folder_rounded),
        label: const Text('Create Folder'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: folderState.isLoading
              ? const Center(child: LoadingWidget(message: 'Loading folders…'))
              : rootFolders.isEmpty
                  ? const Center(
                      child: EmptyStateCard(
                        icon: Icons.folder_off_rounded,
                        message: 'No folders yet. Tap "Create Folder" to add one.',
                      ),
                    )
                  : ListView.separated(
                      itemCount: rootFolders.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) {
                        final folder = rootFolders[i];
                        final childCount = folderState.folders
                            .where((f) => f.parentId == folder.id)
                            .length;
                        final cover = coverForFolder(
                          folderId: folder.id,
                          allMedia: mediaState.allMedia,
                          allAlbums: albumState.allAlbums,
                        );
                        return FolderTile(
                          folder: folder,
                          cover: cover,
                          childFolderCount: childCount,
                          onTap: () => Navigator.of(context).pushNamed(
                            AppRoutes.adminFolderDetails,
                            arguments: folder.id,
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
