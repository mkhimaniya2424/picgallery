import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/media_format_utils.dart';
import '../../../models/media_model.dart';
import '../../../widgets/media/media_thumb_badges.dart';

/// Responsive grid used by Album Details' "Recent Photos" section.
///
/// Reuses the same glass-card container language as the rest of the
/// screen (see `AlbumDetailsHeader` / the old `RecentPhotosPlaceholder`)
/// and falls back to an attractive empty state when the album has no
/// media yet. This widget only renders — all data comes from the shared
/// `mediaProvider`, so a future Firebase-backed repository swap needs no
/// changes here.
class AlbumMediaGrid extends StatelessWidget {
  final List<MediaModel> media;
  final VoidCallback onAddMedia;
  final ValueChanged<MediaModel> onTapMedia;

  const AlbumMediaGrid({
    super.key,
    required this.media,
    required this.onAddMedia,
    required this.onTapMedia,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface
            : Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: media.isEmpty
            ? _EmptyState(
                key: const ValueKey('album-media-empty'),
                onAddMedia: onAddMedia)
            : _MediaGridView(
                key: const ValueKey('album-media-grid'),
                media: media,
                onTapMedia: onTapMedia,
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAddMedia;

  const _EmptyState({super.key, required this.onAddMedia});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppColors.softWash,
              shape: BoxShape.circle,
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
            ),
            child: const Center(
              child: Text('📷', style: TextStyle(fontSize: 30)),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No photos yet',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.textOnDark : AppColors.text),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Upload your first photo or video',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.subtitleOnDark : AppColors.subtitle),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onAddMedia,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Media'),
          ),
        ],
      ),
    );
  }
}

class _MediaGridView extends StatelessWidget {
  final List<MediaModel> media;
  final ValueChanged<MediaModel> onTapMedia;

  const _MediaGridView(
      {super.key, required this.media, required this.onTapMedia});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double tileMinWidth = 96;
        final width = constraints.maxWidth;
        final crossAxisCount = (width ~/ tileMinWidth).clamp(3, 5);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1,
          ),
          itemCount: media.length,
          itemBuilder: (context, i) {
            final m = media[i];
            return _MediaThumb(media: m, onTap: () => onTapMedia(m));
          },
        );
      },
    );
  }
}

class _MediaThumb extends StatefulWidget {
  final MediaModel media;
  final VoidCallback onTap;

  const _MediaThumb({required this.media, required this.onTap});

  @override
  State<_MediaThumb> createState() => _MediaThumbState();
}

class _MediaThumbState extends State<_MediaThumb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.fast,
  )..forward();
  late final Animation<double> _fade =
      CurvedAnimation(parent: _controller, curve: Curves.easeOut);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.media;
    final isVideo = m.type == MediaType.video;

    return FadeTransition(
      opacity: _fade,
      child: GestureDetector(
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (m.displayPath.isNotEmpty || m.displayThumbnailPath.isNotEmpty)
                Builder(
                  builder: (context) {
                    final path = isVideo ? m.displayThumbnailPath : m.displayPath;
                    final isNetwork = path.startsWith('http://') ||
                        path.startsWith('https://');
                    if (isNetwork) {
                      return Image.network(
                        path,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallback(isVideo: isVideo),
                      );
                    } else if (path.isNotEmpty && File(path).existsSync()) {
                      return Image.file(
                        File(path),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallback(isVideo: isVideo),
                      );
                    }
                    return _fallback(isVideo: isVideo);
                  },
                )
              else
                _fallback(isVideo: isVideo),
              if (isVideo)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.42)
                      ],
                    ),
                  ),
                ),
              if (isVideo)
                const Center(
                  child: Icon(Icons.play_circle_fill_rounded,
                      color: Colors.white, size: 30),
                ),
              if (isVideo && m.duration != null)
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      MediaFormatUtils.formatDuration(m.duration),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              // Task 21.12: heart/comment engagement badges, bottom-left so
              // they never collide with the video duration badge above
              // (bottom-right) — hidden automatically when both counts are 0.
              MediaThumbBadges(
                likeCount: m.likeCount,
                commentCount: m.commentCount,
                alignment: Alignment.bottomLeft,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback({required bool isVideo}) {
    final m = widget.media;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(m.gradientArgb.first), Color(m.gradientArgb[1])],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          isVideo ? Icons.videocam_rounded : Icons.image_rounded,
          color: Colors.white.withValues(alpha: 0.92),
          size: 26,
        ),
      ),
    );
  }
}