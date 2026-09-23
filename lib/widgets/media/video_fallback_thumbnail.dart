import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../models/media_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/media_format_utils.dart';

class VideoFallbackThumbnail extends StatefulWidget {
  final MediaModel media;
  final BoxFit fit;

  const VideoFallbackThumbnail({
    super.key,
    required this.media,
    this.fit = BoxFit.cover,
  });

  @override
  State<VideoFallbackThumbnail> createState() => _VideoFallbackThumbnailState();
}

class _VideoFallbackThumbnailState extends State<VideoFallbackThumbnail> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    final url = widget.media.remoteUrl;
    if (url == null || url.isEmpty) {
      if (mounted) {
        setState(() => _error = true);
      }
      return;
    }

    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing VideoPlayer fallback thumbnail: $e');
      if (mounted) {
        setState(() => _error = true);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Widget _placeholder() {
    final colors = widget.media.gradientArgb.length >= 2
        ? [
            Color(widget.media.gradientArgb.first),
            Color(widget.media.gradientArgb[1])
          ]
        : [AppColors.softWash.colors.first, AppColors.softWash.colors.last];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.play_circle_fill_rounded,
          color: Colors.white.withValues(alpha: 0.94),
          size: 26,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error || _controller == null) {
      return _placeholder();
    }
    if (!_initialized) {
      // Show placeholder while initializing metadata
      return Stack(
        fit: StackFit.expand,
        children: [
          _placeholder(),
          Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: FittedBox(
            fit: widget.fit,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: IgnorePointer(child: VideoPlayer(_controller!)),
            ),
          ),
        ),
        // Always render a play button over it so users know it's a video
        Center(
          child: Icon(
            Icons.play_circle_fill_rounded,
            color: Colors.white.withValues(alpha: 0.94),
            size: 26,
          ),
        ),
        if (widget.media.duration == null && _controller != null)
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                MediaFormatUtils.formatDuration(_controller!.value.duration),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
