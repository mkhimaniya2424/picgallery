import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../models/album_model.dart';
import '../../models/media_model.dart';
import '../../providers/client_gallery_provider.dart';
import '../../providers/media_likes_comments_provider.dart';
import '../media/image_viewer_screen.dart';
import '../media/video_player_screen.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/empty_state_card.dart';
import '../../widgets/common/inline_error_banner.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/media/media_comments_section.dart';
import '../../widgets/media/media_thumb_badges.dart';

/// Full photo-by-photo browser for a single album inside a studio's Shared
/// Gallery.
///
/// Fetches real media files from `GET /client/studios/{studio_id}/albums/{album_id}/media`
/// and displays them in a premium grid. Tapping a photo opens the image viewer;
/// tapping a video launches the video player.
class SharedAlbumPreviewScreen extends ConsumerStatefulWidget {
  final String studioId;
  final AlbumModel album;

  const SharedAlbumPreviewScreen({
    super.key,
    required this.studioId,
    required this.album,
  });

  @override
  ConsumerState<SharedAlbumPreviewScreen> createState() => _SharedAlbumPreviewScreenState();
}

class _SharedAlbumPreviewScreenState extends ConsumerState<SharedAlbumPreviewScreen> {
  List<MediaModel> _mediaList = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(clientGalleryRepositoryProvider);
      final media = await repo.fetchSharedAlbumMedia(widget.studioId, widget.album.id);
      if (mounted) {
        setState(() {
          _mediaList = media;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _openMedia(int index) {
    final media = _mediaList[index];
    final allIds = _mediaList.map((m) => m.id).toList();

    if (media.type == MediaType.video) {
      Navigator.of(context).pushNamed(
        AppRoutes.videoPlayer,
        arguments: VideoPlayerArgs(
          mediaId: media.id,
          mediaIds: allIds,
          initialIndex: index,
          mediaItems: _mediaList,
          readOnly: true,
        ),
      );
    } else {
      Navigator.of(context).pushNamed(
        AppRoutes.imageViewer,
        arguments: ImageViewerArgs(
          mediaIds: allIds,
          initialIndex: index,
          mediaItems: _mediaList,
          readOnly: true,
        ),
      );
    }
  }

  /// Opens [media]'s comments in a bottom sheet. Same
  /// [MediaCommentsSection]/[mediaLikesCommentsProvider] wiring as
  /// `image_viewer_screen.dart` — the backend's like/comment endpoints
  /// accept any authenticated user with access to the media (studio
  /// owner, or a client viewing a shared album), not just the owner.
  void _openComments(MediaModel media) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: Consumer(builder: (context, ref, _) {
                final lc = ref.watch(mediaLikesCommentsProvider);
                if (!lc.hasFetchedComments(media.id)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(mediaLikesCommentsProvider).fetchComments(media.id);
                  });
                }
                return MediaCommentsSection(
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
                );
              }),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      appBar: CustomAppBar(title: widget.album.name, showBack: true),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadMedia,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _mediaList.isEmpty) {
      return const Center(child: LoadingWidget(message: 'Loading gallery media…'));
    }

    if (_error != null && _mediaList.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InlineErrorBanner(message: _error!),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton.icon(
                onPressed: _loadMedia,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_mediaList.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: const EmptyStateCard(
            icon: Icons.photo_library_outlined,
            message: 'No photos or videos in this album yet.',
          ),
        ),
      );
    }

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1.0,
      ),
      itemCount: _mediaList.length,
      itemBuilder: (context, index) {
        final media = _mediaList[index];
        final url = media.remoteThumbnailUrl ?? media.remoteUrl;
        // Seed once from the server-provided like_count/is_liked_by_me
        // (harmless no-op after the first build or a real toggle).
        ref.read(mediaLikesCommentsProvider).seedLikeState(media);
        final likeState = ref.watch(mediaLikesCommentsProvider).likeStateFor(media.id);
        return GestureDetector(
          onTap: () => _openMedia(index),
          child: Hero(
            tag: 'shared_media_${media.id}',
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (url != null)
                    Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_rounded, color: AppColors.subtitle, size: 24),
                      ),
                    )
                  else
                    const Center(
                      child: Icon(Icons.image_outlined, color: AppColors.subtitle, size: 24),
                    ),
                  if (media.type == MediaType.video)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  // Passive engagement summary (Task 21.13) — surfaces the
                  // server-seeded comment_count (Task 21.14-21.16) that the
                  // interactive chip below never showed a number for. Kept
                  // separate from the bottom-left chips since those are tap
                  // targets (toggle like / open comments) and MediaThumbBadges
                  // is deliberately non-interactive, auto-hiding at 0/0.
                  Positioned(
                    top: 4,
                    right: 4,
                    child: MediaThumbBadges(
                      likeCount: likeState.count,
                      commentCount: media.commentCount,
                      alignment: Alignment.topRight,
                    ),
                  ),
                  // Like + comment overlay — tap targets stop the tap from
                  // bubbling up to the tile's own onTap (which opens the
                  // fullscreen viewer instead).
                  Positioned(
                    left: 4,
                    bottom: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () =>
                              ref.read(mediaLikesCommentsProvider).toggleLike(media.id),
                          child: _TileOverlayChip(
                            icon: likeState.liked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            iconColor: likeState.liked ? Colors.redAccent : Colors.white,
                            label: likeState.count > 0 ? '${likeState.count}' : null,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _openComments(media),
                          child: const _TileOverlayChip(
                            icon: Icons.mode_comment_outlined,
                            iconColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Small pill used for the like/comment overlay on each shared-album
/// grid tile — icon plus an optional count label.
class _TileOverlayChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String? label;

  const _TileOverlayChip({required this.icon, required this.iconColor, this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          if (label != null) ...[
            const SizedBox(width: 3),
            Text(
              label!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}