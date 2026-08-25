import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/media_format_utils.dart';
import '../../models/media_model.dart';
import '../../providers/auth_providers.dart' show apiClientProvider;
import '../../providers/media_provider.dart';
import '../../providers/media_likes_comments_provider.dart';
import '../../services/download_service.dart';
import '../../services/download_service_impl.dart';
import '../../services/media_file_cache.dart';
import '../../services/share_service.dart';
import '../../services/share_service_impl.dart';
import '../../widgets/media/media_like_button.dart';
import '../../widgets/media/media_comments_section.dart';
import '../../widgets/media/download_complete_bottom_sheet.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/empty_state_card.dart';
import 'image_viewer_screen.dart';
import 'media_batch_workflows.dart';
import 'video_player_screen.dart';

/// Route arguments for [MediaDetailsScreen].
///
/// [mediaIds] is the ordered id list of the grid/search results the user
/// came from, so the Viewer can swipe through that same set. When absent
/// (e.g. a deep link), Details falls back to a single-item set.
class MediaDetailsArgs {
  final String mediaId;
  final List<String>? mediaIds;
  final String? heroTag;

  const MediaDetailsArgs({required this.mediaId, this.mediaIds, this.heroTag});
}

/// Media Details — full metadata + primary actions (favorite, delete,
/// open full-screen viewer/player) for a single photo or video.
class MediaDetailsScreen extends ConsumerWidget {
  final String mediaId;
  final List<String>? mediaIds;
  final String? heroTag;

  const MediaDetailsScreen({
    super.key,
    required this.mediaId,
    this.mediaIds,
    this.heroTag,
  });

  static const ShareService _shareService = ShareServiceImpl();
  static const DownloadService _downloadService = DownloadServiceImpl();
  static const MediaFileCache _fileCache = MediaFileCache();

  MediaModel? _find(List<MediaModel> all, String id) {
    for (final m in all) {
      if (m.id == id) return m;
    }
    return null;
  }

  Future<void> _shareMedia(BuildContext context, MediaModel media) async {
    if (kIsWeb) {
      final result = await _fileCache.bytesFor(media);
      if (result == null) return;
      if (!context.mounted) return;
      await _shareService.shareMediaBytes(
        context: context,
        bytes: result.bytes,
        fileName: result.fileName,
      );
      return;
    }
    final filePath = await _fileCache.localPathFor(media);
    if (filePath == null) return;
    if (!context.mounted) return;
    await _shareService.shareMedia(context: context, filePath: filePath);
  }

  Future<void> _downloadMedia(BuildContext context, WidgetRef ref, MediaModel media) async {
    bool saved = false;
    String? localPath;
    final apiClient = ref.read(apiClientProvider);

    if (kIsWeb) {
      final result = await _fileCache.bytesFor(media);
      if (result == null) return;
      if (!context.mounted) return;
      saved = await _downloadService.downloadBytes(
        context: context,
        bytes: result.bytes,
        fileName: result.fileName,
        mediaId: media.id,
        apiClient: apiClient,
      );
    } else {
      localPath = await _fileCache.localPathFor(media);
      if (localPath == null) return;
      if (!context.mounted) return;
      saved = await _downloadService.downloadOriginal(
        context: context,
        filePath: localPath,
        mediaId: media.id,
        apiClient: apiClient,
      );
    }

    if (saved && context.mounted) {
      await DownloadCompleteBottomSheet.show(
        context: context,
        fileName: media.fileName,
        size: media.size,
        thumbnailPath: localPath,
        filePath: localPath,
        media: media,
      );
    }
  }

  /// Saves to the OS photo/video gallery on mobile. On web there's no
  /// gallery to write into and no filesystem path to hand `gal`, so this
  /// mirrors [_downloadMedia]'s web branch and falls back to the same
  /// in-memory "save as" flow. Permission prompts and the success/failure
  /// snackbar are handled inside [DownloadService.saveToGallery] itself.
  Future<void> _saveMediaToGallery(BuildContext context, WidgetRef ref, MediaModel media) async {
    bool saved = false;
    String? localPath;
    final apiClient = ref.read(apiClientProvider);

    if (kIsWeb) {
      final result = await _fileCache.bytesFor(media);
      if (result == null) return;
      if (!context.mounted) return;
      saved = await _downloadService.downloadBytes(
        context: context,
        bytes: result.bytes,
        fileName: result.fileName,
        mediaId: media.id,
        apiClient: apiClient,
      );
    } else {
      localPath = await _fileCache.localPathFor(media);
      if (localPath == null) return;
      if (!context.mounted) return;
      saved = await _downloadService.saveToGallery(
        context: context,
        filePath: localPath,
        mediaId: media.id,
        apiClient: apiClient,
      );
    }

    if (saved && context.mounted) {
      await DownloadCompleteBottomSheet.show(
        context: context,
        fileName: media.fileName,
        size: media.size,
        thumbnailPath: localPath,
        filePath: localPath,
        media: media,
      );
    }
  }

  Future<void> _renameMedia(
      BuildContext context, WidgetRef ref, MediaModel media) async {
    final nameController = TextEditingController(text: media.fileName);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename media'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Enter new file name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(nameController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName == null || newName.trim().isEmpty) return;
    await ref
        .read(mediaProvider)
        .renameMediaById(mediaId: media.id, newFileName: newName);
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, MediaModel media) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete media?'),
        content: const Text('This removes the media from your library.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final controller = ref.read(mediaProvider);
    controller.toggleSelected(media.id);
    await controller.batchDelete();

    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(mediaProvider);
    final media = _find(c.allMedia, mediaId);

    if (media == null) {
      return const Scaffold(
        appBar: CustomAppBar(title: 'Media', showBack: true),
        body: Center(
          child: EmptyStateCard(
            icon: Icons.search_off_rounded,
            message: 'This media item no longer exists.',
          ),
        ),
      );
    }

    final ids = mediaIds != null ? mediaIds!.toSet().toList() : [media.id];
    final index = ids.indexOf(media.id);
    final safeIndex = index == -1 ? 0 : index;

    final path = media.displayPath;
    final isNetwork = media.isDisplayPathNetwork;
    final file = (!isNetwork && path.isNotEmpty) ? File(path) : null;
    final hasRealFile = (file != null && file.existsSync()) || isNetwork;

    // Video poster frame: separate from [path]/[file] above, since a
    // video's `displayPath` points at the video file itself (which
    // Image.* can't decode) — `displayThumbnailPath` is the actual
    // generated poster-frame JPEG (local or `thumbnail_url`).
    final videoThumbPath = media.displayThumbnailPath;
    final videoThumbIsNetwork = videoThumbPath.startsWith('http://') ||
        videoThumbPath.startsWith('https://');
    final videoThumbFile =
        (!videoThumbIsNetwork && videoThumbPath.isNotEmpty)
            ? File(videoThumbPath)
            : null;
    final hasVideoThumb = (videoThumbFile != null && videoThumbFile.existsSync()) ||
        (videoThumbIsNetwork && videoThumbPath.isNotEmpty);

    void openFullScreen() {
      Navigator.of(context).pushNamed(
        media.type == MediaType.photo
            ? AppRoutes.imageViewer
            : AppRoutes.videoPlayer,
        arguments: media.type == MediaType.photo
            ? ImageViewerArgs(mediaIds: ids, initialIndex: safeIndex)
            : VideoPlayerArgs(
                mediaId: media.id,
                mediaIds: ids,
                initialIndex: safeIndex,
              ),
      );
    }

    return Scaffold(
      appBar: CustomAppBar(
        title:
            media.type == MediaType.photo ? 'Photo Details' : 'Video Details',
        showBack: true,
        actions: [
          IconButton(
            tooltip:
                media.isFavorite ? 'Remove from favorites' : 'Add to favorites',
            onPressed: () => ref.read(mediaProvider).toggleFavorite(media.id),
            icon: Icon(
              media.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: media.isFavorite ? AppColors.accent : AppColors.text,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _MediaStitchBottomBar(
        isFavorite: media.isFavorite,
        isVideo: media.type == MediaType.video,
        onPrimary: openFullScreen,
        onFavorite: () => ref.read(mediaProvider).toggleFavorite(media.id),
        onDelete: () => _confirmDelete(context, ref, media),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppShadows.soft(
                    AppColors.primary,
                    opacity: 0.15,
                    blur: 40,
                    y: 16,
                  ),
                ),
                child: GestureDetector(
                  onTap: openFullScreen,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: AspectRatio(
                      aspectRatio: media.width > 0 && media.height > 0
                          ? media.width / media.height
                          : 1,
                      child: Hero(
                        tag: heroTag ?? 'hero-media-${media.id}',
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (hasRealFile && media.type == MediaType.photo)
                              isNetwork
                                  ? Image.network(path,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _MediaGradientPlaceholder(
                                              media: media))
                                  : Image.file(file!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _MediaGradientPlaceholder(
                                              media: media))
                            else if (media.type == MediaType.video &&
                                hasVideoThumb)
                              videoThumbIsNetwork
                                  ? Image.network(videoThumbPath,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _MediaGradientPlaceholder(
                                              media: media))
                                  : Image.file(videoThumbFile!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _MediaGradientPlaceholder(
                                              media: media))
                            else
                              _MediaGradientPlaceholder(media: media),
                            // Play affordance sits on top of whatever's
                            // behind it (real poster frame or the
                            // gradient fallback) — a video is always
                            // tappable-to-play here, whether or not a
                            // thumbnail was available to generate.
                            if (media.type == MediaType.video)
                              Center(
                                child: Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: Colors.white.withValues(alpha: 0.92),
                                  size: 56,
                                ),
                              ),
                            if (media.type == MediaType.video)
                              Positioned(
                                right: AppSpacing.md,
                                bottom: AppSpacing.md,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    MediaFormatUtils.formatDuration(
                                        media.duration),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Extra actions (Share / Download / Move / Copy / Rename) —
              // previously only available from the full-screen player, now
              // also surfaced here on the Details page.
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  _DetailsActionChip(
                    icon: Icons.ios_share_rounded,
                    label: 'Share',
                    onTap: () => _shareMedia(context, media),
                  ),
                  _DetailsActionChip(
                    icon: Icons.download_rounded,
                    label: 'Download',
                    onTap: () => _downloadMedia(context, ref, media),
                  ),
                  _DetailsActionChip(
                    icon: Icons.add_photo_alternate_rounded,
                    label: 'Save to Gallery',
                    onTap: () => _saveMediaToGallery(context, ref, media),
                  ),
                  _DetailsActionChip(
                    icon: Icons.drive_file_move_rounded,
                    label: 'Move',
                    onTap: () => MediaBatchWorkflows.openMove(
                      context: context,
                      mediaIds: [media.id],
                    ),
                  ),
                  _DetailsActionChip(
                    icon: Icons.copy_all_rounded,
                    label: 'Copy',
                    onTap: () => MediaBatchWorkflows.openCopy(
                      context: context,
                      mediaIds: [media.id],
                    ),
                  ),
                  _DetailsActionChip(
                    icon: Icons.drive_file_rename_outline_rounded,
                    label: 'Rename',
                    onTap: () => _renameMedia(context, ref, media),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Likes + Comments
              Consumer(builder: (context, ref, _) {
                final lc = ref.watch(mediaLikesCommentsProvider);

                // Prime the like cache from the server-seeded fields on
                // `media` (MediaRead.like_count / is_liked_by_me) the
                // first time this media is shown, so the button reflects
                // reality immediately instead of the (false, 0) default.
                // No-op once a real state is already cached.
                lc.seedLikeState(media);
                final likeState = lc.likeStateFor(media.id);

                // Fetch comments once per media, deferred until after this
                // frame finishes building — calling fetchComments()
                // directly here (synchronously, during build) triggers
                // notifyListeners() before the widget tree is done
                // building, which Riverpod disallows ("Tried to modify a
                // provider while the widget tree was building").
                if (!lc.hasFetchedComments(media.id)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(mediaLikesCommentsProvider).fetchComments(media.id);
                  });
                }
                if (!lc.hasFetchedLikes(media.id)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(mediaLikesCommentsProvider).fetchLikes(media.id);
                  });
                }
                
                final likes = lc.likesForMedia(media.id);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        MediaLikeButton(
                          liked: likeState.liked,
                          likeCount: likeState.count,
                          onToggle: () => lc.toggleLike(media.id),
                        ),
                      ],
                    ),
                    if (likes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                        child: Text(
                          'Liked by: ${likes.map((l) => l.userFullName).join(', ')}',
                          style: TextStyle(color: AppColors.subtitle, fontSize: 12),
                        ),
                      ),
                    const Divider(height: 24),
                    MediaCommentsSection(
                      comments: lc.commentsForMedia(media.id),
                      currentUserId: lc.currentUserId,
                      isLoading: lc.isLoading,
                      onAddTopLevel: (text) => lc.addComment(
                        mediaId: media.id,
                        text: text,
                        parentId: null,
                      ),
                      onReply: (parentId, text) => lc.addComment(
                        mediaId: media.id,
                        text: text,
                        parentId: parentId,
                      ),
                      onEdit: (commentId, newText) => lc.editOwnComment(
                        commentId: commentId,
                        newText: newText,
                      ),
                      onDelete: (commentId) => lc.deleteOwnComment(
                        commentId: commentId,
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

/// Light-themed pill button used on the Details page's action row.
/// (Mirrors `_ActionChip` in [VideoPlayerScreen] but tuned for a white
/// card background instead of a dark video overlay.)
class _MediaGradientPlaceholder extends StatelessWidget {
  final MediaModel media;
  const _MediaGradientPlaceholder({required this.media});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(media.gradientArgb.first),
            Color(media.gradientArgb[1]),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: media.type == MediaType.photo
          ? Center(
              child: Icon(
                Icons.image_rounded,
                color: Colors.white.withValues(alpha: 0.92),
                size: 56,
              ),
            )
          : null,
    );
  }
}

class _DetailsActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DetailsActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: AppColors.primary),
      label: Text(
        label,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      onPressed: onTap,
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    );
  }
}

class _MediaStitchBottomBar extends StatelessWidget {
  final bool isVideo;
  final bool isFavorite;
  final VoidCallback onPrimary;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;

  const _MediaStitchBottomBar({
    required this.isVideo,
    required this.isFavorite,
    required this.onPrimary,
    required this.onFavorite,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.78),
          border: const Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: FilledButton.icon(
                onPressed: onPrimary,
                icon: Icon(
                  isVideo ? Icons.play_arrow_rounded : Icons.zoom_in_rounded,
                ),
                label: Text(
                  isVideo ? 'Play Video' : 'View Full Screen',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: IconButton.filledTonal(
                onPressed: onFavorite,
                icon: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                ),
                tooltip: isFavorite ? 'Unfavorite' : 'Favorite',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: IconButton.filledTonal(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Delete',
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}