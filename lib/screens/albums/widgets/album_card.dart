import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/album_model.dart';
import '../../../providers/media_provider.dart';
import '../../../models/media_model.dart';
import '../../../widgets/media/media_thumb.dart';
import 'album_cover_placeholder.dart';

class AlbumCard extends ConsumerWidget {
  const AlbumCard({
    super.key,
    required this.album,
    required this.onToggleFavorite,
    this.onTap,
    this.onEdit,
    this.onMove,
    this.onDelete,
    this.compact = false,
  });

  final AlbumModel album;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onMove;
  final VoidCallback? onDelete;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _mediaState = ref.watch(mediaProvider);
    final _albumMedia = _mediaState.allMedia
        .where((m) => !m.isDeleted)
        .where((m) => m.albumId == album.id)
        .toList(growable: false);

    final photoCount =
        _albumMedia.where((m) => m.type == MediaType.photo).length;
    final videoCount =
        _albumMedia.where((m) => m.type == MediaType.video).length;
    final folderCount =
        _albumMedia.map((m) => m.folderId).whereType<String>().toSet().length;

    // Real cover photo for this album, preferring a photo over a video
    // thumbnail so the card shows something crisp; falls back to the
    // gradient placeholder only when the album truly has no media yet.
    MediaModel? cover;
    for (final m in _albumMedia) {
      if (m.type == MediaType.photo) {
        cover = m;
        break;
      }
    }
    cover ??= _albumMedia.isNotEmpty ? _albumMedia.first : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: compact
              ? _buildCompactCard(
                  cover: cover,
                  photoCount: photoCount,
                  videoCount: videoCount,
                  folderCount: folderCount,
                )
              : _buildGridCard(
                  cover: cover,
                  photoCount: photoCount,
                  videoCount: videoCount,
                  folderCount: folderCount,
                ),
        ),
      ),
    );
  }

  Widget _buildCompactCard(
      {MediaModel? cover,
      required int photoCount,
      required int videoCount,
      required int folderCount}) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox(
              width: 90,
              height: 90,
              child: cover != null
                  ? MediaThumb(media: cover)
                  : AlbumCoverPlaceholder(
                      gradient: album.gradient,
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  album.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$photoCount Photos • $videoCount Videos',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.subtitle,
                  ),
                ),
                Text(
                  '$folderCount Folders',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.subtitle,
                  ),
                ),
                const SizedBox(height: 6),
                _BottomRow(
                  isFavorite: album.isFavorite,
                  onToggleFavorite: onToggleFavorite,
                  onEdit: onEdit,
                  onMove: onMove,
                  onDelete: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridCard(
      {MediaModel? cover,
      required int photoCount,
      required int videoCount,
      required int folderCount}) {
    // mainAxisSize.min + a fixed gap (instead of a Spacer) so the
    // bottom row sits right under the text instead of being pushed to
    // the bottom of a tall grid cell, which is what was leaving a big
    // empty gap in the middle of every card.
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: cover != null
                  ? MediaThumb(media: cover)
                  : AlbumCoverPlaceholder(
                      gradient: album.gradient,
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            album.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            folderCount > 0
                ? '$photoCount photos • $videoCount videos • $folderCount folders'
                : '$photoCount photos • $videoCount videos',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.subtitle,
            ),
          ),
          const SizedBox(height: 4),
          _BottomRow(
            isFavorite: album.isFavorite,
            onToggleFavorite: onToggleFavorite,
            onEdit: onEdit,
            onMove: onMove,
            onDelete: onDelete,
          ),
        ],
      ),
    );
  }
}

enum _AlbumMenuAction { edit, move, delete }

class _BottomRow extends StatelessWidget {
  const _BottomRow({
    required this.isFavorite,
    required this.onToggleFavorite,
    this.onEdit,
    this.onMove,
    this.onDelete,
  });

  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onEdit;
  final VoidCallback? onMove;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final hasMenu = onEdit != null || onMove != null || onDelete != null;

    return Row(
      children: [
        IconButton(
          onPressed: onToggleFavorite,
          padding: EdgeInsets.zero,
          splashRadius: 18,
          constraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 32,
          ),
          icon: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 20,
            color: isFavorite ? AppColors.accent : AppColors.subtitle,
          ),
        ),
        const Spacer(),
        if (hasMenu)
          PopupMenuButton<_AlbumMenuAction>(
            padding: EdgeInsets.zero,
            splashRadius: 18,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            tooltip: 'More actions',
            icon: const Icon(
              Icons.more_vert_rounded,
              size: 20,
              color: AppColors.subtitle,
            ),
            onSelected: (action) {
              switch (action) {
                case _AlbumMenuAction.edit:
                  onEdit?.call();
                  break;
                case _AlbumMenuAction.move:
                  onMove?.call();
                  break;
                case _AlbumMenuAction.delete:
                  onDelete?.call();
                  break;
              }
            },
            itemBuilder: (_) => [
              if (onEdit != null)
                const PopupMenuItem(
                  value: _AlbumMenuAction.edit,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit'),
                  ),
                ),
              if (onMove != null)
                const PopupMenuItem(
                  value: _AlbumMenuAction.move,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.drive_file_move_rounded),
                    title: Text('Move to folder'),
                  ),
                ),
              if (onDelete != null)
                const PopupMenuItem(
                  value: _AlbumMenuAction.delete,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading:
                        Icon(Icons.delete_outline_rounded, color: Colors.red),
                    title: Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
