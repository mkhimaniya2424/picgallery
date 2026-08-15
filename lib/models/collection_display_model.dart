import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'album_model.dart';
import 'gallery_collection_model.dart';

/// Presentation-only adapter for the Collections module UI.
///
/// This is intentionally NOT a persisted/repository model — it is derived
/// at build time from the real [GalleryCollectionModel] (API-backed, via
/// `galleryCollectionsProvider`) joined with the real [AlbumModel]
/// entries it references (via `albumProvider`). Nothing here is
/// hardcoded: every field is computed from whatever the studio currently
/// has stored on the server. Collections with no albums yet simply
/// resolve to zero counts / empty preview lists / a placeholder cover
/// instead of any sample content.
///
/// A couple of fields don't have a backing data source *yet* in this app
/// (there's no "shared collection" concept, and "last opened" isn't
/// tracked separately from "last updated"). Those are clearly called out
/// below and default to safe, honest values rather than fabricated ones —
/// swap them for real fields the moment that data exists.
@immutable
class CollectionDisplayModel {
  final String id;
  final String title;

  /// Number of albums currently linked to this collection.
  final int albumCount;

  /// Sum of every photo + video across every album linked to this
  /// collection.
  final int mediaCount;

  final DateTime updatedAt;

  /// No separate "last opened" tracking exists on
  /// [GalleryCollectionModel] today, so this mirrors [updatedAt]. Wire
  /// this to a real last-opened timestamp once the app tracks one.
  final DateTime lastOpenedAt;

  /// True when at least one linked album is favorited. There's no
  /// dedicated "favorite collection" flag yet, so this is the closest
  /// honest signal available from real data.
  final bool isFavorite;

  /// Always false today — picgallery has no sharing model for
  /// collections yet (only per-gallery share links). Left in place so
  /// the badge lights up automatically once that ships.
  final bool isShared;

  /// Up to 6 linked albums, in stored order — used for the overlapping
  /// preview-avatar stack and to pick the cover.
  final List<AlbumModel> previewAlbums;

  const CollectionDisplayModel({
    required this.id,
    required this.title,
    required this.albumCount,
    required this.mediaCount,
    required this.updatedAt,
    required this.lastOpenedAt,
    required this.isFavorite,
    required this.isShared,
    required this.previewAlbums,
  });

  AlbumModel? get coverAlbum =>
      previewAlbums.isEmpty ? null : previewAlbums.first;

  bool get isEmpty => previewAlbums.isEmpty;

  /// Deterministic fallback gradient for collections that don't have any
  /// albums yet (so there's nothing to sample a real cover/tint from).
  /// Picked from the app's existing palette, varied per-collection via
  /// its id so an empty state doesn't look duplicated across cards.
  List<Color> get fallbackGradient {
    const palette = [
      [AppColors.primary, AppColors.secondary],
      [AppColors.secondary, AppColors.accent],
      [AppColors.primary, AppColors.accent],
      [AppColors.gold, AppColors.accent],
    ];
    final idx = id.hashCode.abs() % palette.length;
    return palette[idx];
  }
}

/// Builds the display models the Collections screen renders from the two
/// real providers involved — no network stubs, no demo data.
List<CollectionDisplayModel> buildCollectionDisplayModels({
  required List<GalleryCollectionModel> collections,
  required List<AlbumModel> allAlbums,
}) {
  final albumsById = {for (final a in allAlbums) a.id: a};

  return collections.map((c) {
    final linked = c.galleryIds
        .map((id) => albumsById[id])
        .whereType<AlbumModel>()
        .toList(growable: false);

    final mediaCount = linked.fold<int>(
      0,
      (sum, a) => sum + a.photoCount + a.videoCount,
    );

    return CollectionDisplayModel(
      id: c.id,
      title: c.name,
      albumCount: linked.length,
      mediaCount: mediaCount,
      updatedAt: c.updatedAt,
      lastOpenedAt: c.updatedAt,
      isFavorite: linked.any((a) => a.isFavorite),
      isShared: false,
      previewAlbums: linked.take(6).toList(growable: false),
    );
  }).toList(growable: false);
}
