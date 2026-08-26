import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../models/media_model.dart';
import '../../providers/face_search_provider.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/empty_state_card.dart';
import '../../widgets/media/media_thumb.dart';
import '../media/image_viewer_screen.dart';
import '../media/video_player_screen.dart';

class FaceSearchResultsScreen extends ConsumerWidget {
  const FaceSearchResultsScreen({super.key});

  void _openMedia(BuildContext context, List<MediaModel> allMedia, int index) {
    final media = allMedia[index];
    final allIds = allMedia.map((m) => m.id).toList();

    if (media.type == MediaType.video) {
      Navigator.of(context).pushNamed(
        AppRoutes.videoPlayer,
        arguments: VideoPlayerArgs(
          mediaId: media.id,
          mediaIds: allIds,
          initialIndex: index,
          mediaItems: allMedia,
        ),
      );
    } else {
      Navigator.of(context).pushNamed(
        AppRoutes.imageViewer,
        arguments: ImageViewerArgs(
          mediaIds: allIds,
          initialIndex: index,
          mediaItems: allMedia,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(faceSearchProvider);
    final results = state.searchResults;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Face Search Results',
        showBack: true,
        actions: [
          IconButton(
            tooltip: 'Search Again',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.read(faceSearchProvider.notifier).reset();
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.faceSearchLanding,
                (route) => route.isFirst,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: results.isEmpty
            ? _buildEmptyState()
            : _buildGrid(context, results.map((r) => r.media).toList()),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: const Center(
        child: EmptyStateCard(
          icon: Icons.search_off_rounded,
          message: 'No matching photos found.\nTry a different selfie or adjust your search.',
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<MediaModel> mediaList) {
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1.0,
      ),
      itemCount: mediaList.length,
      itemBuilder: (context, index) {
        final media = mediaList[index];
        final isVideo = media.type == MediaType.video;

        return GestureDetector(
          onTap: () => _openMedia(context, mediaList, index),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MediaThumb(media: media, fit: BoxFit.cover),
                if (isVideo)
                  Positioned(
                    bottom: 6,
                    right: 6,
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
              ],
            ),
          ),
        );
      },
    );
  }
}