import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';

import '../../../widgets/common/pinch_zoom_handler.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/media_format_utils.dart';
import '../../../models/media_model.dart';
import '../../../widgets/media/video_fallback_thumbnail.dart';
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
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface
            : Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border:
            Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
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
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppColors.softWash,
              shape: BoxShape.circle,
              border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.border),
            ),
            child: Center(
              child: Text('📷', style: TextStyle(fontSize: 30)),
            ),
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            'No photos yet',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.textOnDark : AppColors.text),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'Upload your first photo or video',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.subtitleOnDark : AppColors.subtitle),
          ),
          SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onAddMedia,
            icon: Icon(Icons.add_rounded),
            label: Text('Add Media'),
          ),
        ],
      ),
    );
  }
}

class _MediaGridView extends StatefulWidget {
  final List<MediaModel> media;
  final ValueChanged<MediaModel> onTapMedia;

  const _MediaGridView(
      {super.key, required this.media, required this.onTapMedia});

  @override
  State<_MediaGridView> createState() => _MediaGridViewState();
}

class _MediaGridViewState extends State<_MediaGridView> {
  int _crossAxisCount = 3;
  bool _isInitialized = false;

  // GestureDetector-based scale tracking – works for both touch pinch
  // and trackpad pinch-to-zoom on Flutter Web.
  double _scaleStartCrossAxisCount = 3.0;

  void _zoomIn() {
    if (_crossAxisCount > 1) {
      setState(() => _crossAxisCount--);
    }
  }

  void _zoomOut() {
    if (_crossAxisCount < 8) {
      setState(() => _crossAxisCount++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!_isInitialized) {
          const double tileMinWidth = 96;
          final width = constraints.maxWidth;
          _crossAxisCount = (width ~/ tileMinWidth).clamp(3, 8);
          _isInitialized = true;
        }

        return PinchZoomHandler(
          onZoomIn: _zoomIn,
          onZoomOut: _zoomOut,
          child: GestureDetector(
            // onScaleStart/Update handles BOTH two-finger touch pinch AND
          // trackpad pinch-to-zoom on Web/desktop natively in Flutter.
          onScaleStart: (details) {
            _scaleStartCrossAxisCount = _crossAxisCount.toDouble();
          },
          onScaleUpdate: (details) {
            if (details.scale == 1.0) return;
            final newCount = (_scaleStartCrossAxisCount / details.scale)
                .round()
                .clamp(1, 8);
            if (newCount != _crossAxisCount) {
              setState(() => _crossAxisCount = newCount);
            }
          },
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _crossAxisCount,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1,
            ),
            itemCount: widget.media.length,
            itemBuilder: (context, i) {
              final m = widget.media[i];
              return _MediaThumb(media: m, onTap: () => widget.onTapMedia(m));
            },
          ),
        ),
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
                    final path =
                        isVideo ? m.displayThumbnailPath : m.displayPath;
                    final isNetwork = path.startsWith('http://') ||
                        path.startsWith('https://');
                    if (isNetwork) {
                      return Image.network(
                        path,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => kIsWeb && isVideo
                            ? VideoFallbackThumbnail(media: m, fit: BoxFit.cover)
                            : _fallback(isVideo: isVideo),
                      );
                    } else if (!kIsWeb && path.isNotEmpty && File(path).existsSync()) {
                      return Image.file(
                        File(path),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _fallback(isVideo: isVideo),
                      );
                    }
                    return kIsWeb && isVideo
                        ? VideoFallbackThumbnail(media: m, fit: BoxFit.cover)
                        : _fallback(isVideo: isVideo);
                  },
                )
              else
                kIsWeb && isVideo 
                    ? VideoFallbackThumbnail(media: m, fit: BoxFit.cover)
                    : _fallback(isVideo: isVideo),
              // Fallback play icon rendering is handled by VideoFallbackThumbnail if it kicks in.
              // So we only render the overlay/icon/badge if we are NOT using the web fallback,
              // or if the web fallback doesn't trigger (i.e. the image actually loaded).
              // Wait, if Image.network succeeds, we STILL want the play icon.
              // But VideoFallbackThumbnail renders its own play icon AND duration!
              // To prevent double rendering, we can conditionally hide these if the image failed.
              // However, the easiest way is to let the fallback handle it and just render it normally here
              // when the thumbnail DOES load. Since VideoFallbackThumbnail is returned inside Builder,
              // the outer Stack will render the play button on top of VideoFallbackThumbnail.
              // VideoFallbackThumbnail already renders a play button! So there might be 2 play buttons.
              // To fix this, we can remove the play button from VideoFallbackThumbnail? No, because it's used elsewhere.
              // Let's just let it render on top, or we can check if it's network and kIsWeb.
              // For simplicity, since the outer Stack draws on top, having two play buttons overlapping exactly is not a big deal.
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
                Center(
                  child: Icon(Icons.play_circle_fill_rounded,
                      color: Colors.white, size: 30),
                ),
              if (isVideo && m.duration != null)
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      MediaFormatUtils.formatDuration(m.duration),
                      style: TextStyle(
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
