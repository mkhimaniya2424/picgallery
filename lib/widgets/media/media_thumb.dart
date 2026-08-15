import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/media_model.dart';

/// Renders the actual photo (or a video's poster thumbnail) for a
/// [MediaModel], on disk or over the network, falling back to a soft
/// gradient + icon placeholder when there's nothing to show yet (no
/// file, a missing file, or a decode failure) — so a broken/absent
/// path never crashes a card, it just looks like a normal placeholder.
///
/// This is the public, reusable version of the thumbnail logic that
/// used to live only inside `MediaGridScreen` (`_MediaThumbnail`) —
/// pulled out here so album cards, folder tiles, and folder browsing
/// screens can all show a real cover image instead of a static icon.
class MediaThumb extends StatelessWidget {
  final MediaModel media;
  final BoxFit fit;

  const MediaThumb({super.key, required this.media, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final path = media.displayPath;
    final isNetwork = media.isDisplayPathNetwork;

    if (media.type == MediaType.photo) {
      if (isNetwork) {
        return Image.network(
          path,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _Placeholder(media: media),
        );
      }
      if (!kIsWeb && path.isNotEmpty && File(path).existsSync()) {
        return Image.file(
          File(path),
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _Placeholder(media: media),
        );
      }
    } else {
      final thumbPath = media.displayThumbnailPath;
      final isThumbNetwork =
          thumbPath.startsWith('http://') || thumbPath.startsWith('https://');
      if (isThumbNetwork) {
        return Image.network(
          thumbPath,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _Placeholder(media: media),
        );
      } else if (!kIsWeb && thumbPath.isNotEmpty && File(thumbPath).existsSync()) {
        return Image.file(
          File(thumbPath),
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _Placeholder(media: media),
        );
      }
    }
    return _Placeholder(media: media);
  }
}

class _Placeholder extends StatelessWidget {
  final MediaModel media;

  const _Placeholder({required this.media});

  @override
  Widget build(BuildContext context) {
    final colors = media.gradientArgb.length >= 2
        ? [Color(media.gradientArgb.first), Color(media.gradientArgb[1])]
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
          media.type == MediaType.photo ? Icons.image_rounded : Icons.videocam_rounded,
          color: Colors.white.withValues(alpha: 0.94),
          size: 26,
        ),
      ),
    );
  }
}
