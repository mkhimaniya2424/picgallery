import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/media_format_utils.dart';
import '../../models/media_model.dart';
import '../../providers/trash_provider.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/delete_confirmation_dialog.dart';
import '../../widgets/common/snackbar_helper.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deletedMedia = ref.watch(trashProvider);

    return Scaffold(
      
      appBar: CustomAppBar(
        title: 'Trash',
        showBack: true,
        actions: [
          if (deletedMedia.isNotEmpty)
            TextButton(
              onPressed: () => _confirmEmptyTrash(context, ref),
              child: const Text(
                'Empty Trash',
                style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5),
              ),
            ),
        ],
      ),
      body: deletedMedia.isEmpty
          ? _buildEmptyState()
          : LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount =
                    _calculateCrossAxisCount(constraints.maxWidth);
                return GridView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: deletedMedia.length,
                  itemBuilder: (context, index) {
                    final media = deletedMedia[index];
                    return _TrashItemCard(media: media);
                  },
                );
              },
            ),
    );
  }

  int _calculateCrossAxisCount(double width) {
    if (width < 600) return 2;
    if (width < 900) return 3;
    if (width < 1200) return 4;
    return 5;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delete_sweep_rounded,
              color: AppColors.primary,
              size: 56,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Trash is empty',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Deleted items will appear here.',
            style: TextStyle(
              color: AppColors.subtitle,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmEmptyTrash(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDeleteConfirmationDialog(
      context: context,
      title: 'Delete item?',
      message: 'This will permanently delete all items in trash. This action cannot be undone.',
      confirmText: 'Empty All',
    );
    if (!context.mounted) return;
    if (confirmed) {
      await ref.read(trashProvider.notifier).emptyTrash();
      if (context.mounted) {
        SnackBarHelper.showSuccess(context, 'Trash emptied successfully');
      }
    }
  }
}

class _TrashItemCard extends ConsumerWidget {
  final MediaModel media;

  const _TrashItemCard({required this.media});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sizeStr = MediaFormatUtils.formatFileSize(media.size);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildThumbnail(),
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black26, Colors.black87],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      media.type == MediaType.photo ? 'PHOTO' : 'VIDEO',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () =>
                            ref.read(trashProvider.notifier).restore(media.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(60, 28),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.settings_backup_restore_rounded,
                            size: 12),
                        label: const Text('Restore',
                            style: TextStyle(
                                fontSize: 10.5, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        onPressed: () =>
                            _confirmDeletePermanently(context, ref),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.withValues(alpha: 0.2),
                          foregroundColor: Colors.redAccent,
                          minimumSize: const Size(28, 28),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        icon:
                            const Icon(Icons.delete_forever_rounded, size: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  media.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  sizeStr,
                  style: const TextStyle(
                      color: AppColors.subtitle,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    final file = media.filePath.isEmpty ? null : File(media.filePath);
    final hasRealFile = file != null && file.existsSync();

    if (hasRealFile) {
      if (media.type == MediaType.photo) {
        return Image.file(file, fit: BoxFit.cover);
      } else {
        final thumbFile = File(media.thumbnailPath);
        if (media.thumbnailPath.isNotEmpty && thumbFile.existsSync()) {
          return Image.file(thumbFile, fit: BoxFit.cover);
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(media.gradientArgb.first),
            Color(media.gradientArgb[1])
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          media.type == MediaType.photo
              ? Icons.image_rounded
              : Icons.play_circle_fill_rounded,
          color: Colors.white60,
          size: 36,
        ),
      ),
    );
  }

  void _confirmDeletePermanently(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDeleteConfirmationDialog(
      context: context,
      title: 'Delete item?',
      message: 'Do you want to permanently delete "${media.fileName}"? This cannot be undone.',
    );
    if (!context.mounted) return;
    if (confirmed) {
      await ref.read(trashProvider.notifier).deletePermanently(media.id);
      if (context.mounted) {
        SnackBarHelper.showSuccess(context, '"${media.fileName}" permanently deleted');
      }
    }
  }
}
