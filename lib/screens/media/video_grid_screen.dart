import 'package:flutter/material.dart';

import '../../models/media_model.dart';
import 'media_grid_screen.dart';

/// Dedicated Video Grid.
///
/// Reuses the same real Hive-backed [MediaGridScreen] used by Photo Grid /
/// Favorites (mirroring [MediaFavoritesScreen]'s wrapper pattern) with the
/// type filter locked to [MediaType.video], so photos never leak into this
/// view and all selection/move/copy/delete/favorite plumbing keeps working
/// without any duplicated logic.
class VideoGridScreen extends StatelessWidget {
  final String? albumId;
  final String? folderId;

  const VideoGridScreen({super.key, this.albumId, this.folderId});

  @override
  Widget build(BuildContext context) {
    return MediaGridScreen(
      albumId: albumId,
      folderId: folderId,
      type: MediaType.video,
    );
  }
}
