import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// Small pill-badge overlay for a media grid thumbnail, showing a
/// heart+count and/or a comment+count — the at-a-glance engagement
/// signal on a grid tile, as opposed to [MediaLikeButton]'s full
/// tappable detail-view control.
///
/// Each badge only renders when its count is `> 0`; if both counts are
/// zero, [MediaThumbBadges] renders nothing (`SizedBox.shrink`) so grid
/// tiles for media with no engagement stay clean.
///
/// Standalone as of Task 21.11 — not wired into any grid yet. Task
/// 21.12 wires it into `album_media_grid.dart` (studio-side). Task
/// 21.13 wires it into `SharedAlbumPreviewScreen`'s client-side grid.
class MediaThumbBadges extends StatelessWidget {
  final int likeCount;
  final int commentCount;

  /// Where the badge stack sits within the thumbnail's [Stack]. Grids
  /// vary in what else occupies a tile's corners (favorite star, lock
  /// icon, selection checkbox), so the caller picks the corner.
  final Alignment alignment;

  const MediaThumbBadges({
    super.key,
    required this.likeCount,
    required this.commentCount,
    this.alignment = Alignment.bottomLeft,
  });

  bool get _hasAnything => likeCount > 0 || commentCount > 0;

  @override
  Widget build(BuildContext context) {
    if (!_hasAnything) return const SizedBox.shrink();

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (likeCount > 0)
              _Badge(icon: Icons.favorite_rounded, count: likeCount),
            if (likeCount > 0 && commentCount > 0) const SizedBox(width: 4),
            if (commentCount > 0)
              _Badge(icon: Icons.mode_comment_rounded, count: commentCount),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final int count;

  const _Badge({required this.icon, required this.count});

  /// Compact display for large counts — mirrors common social-app
  /// conventions (999 stays exact, 1.2k / 1.2m past that) rather than
  /// letting the pill grow unbounded on a small thumbnail.
  String get _label {
    if (count < 1000) return '$count';
    if (count < 1000000) {
      final k = count / 1000;
      return '${k.toStringAsFixed(k < 10 ? 1 : 0)}k';
    }
    final m = count / 1000000;
    return '${m.toStringAsFixed(m < 10 ? 1 : 0)}m';
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: Colors.white),
            const SizedBox(width: 3),
            Text(
              _label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}