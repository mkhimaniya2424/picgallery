/// Media entity stored locally via Hive.
///
/// Notes:
/// - This model is intentionally generic (works for photos + videos).
/// - UI rendering (thumbnails, resolution labels, durations) is handled
///   by widgets/screens in later phases.
import 'edit_recipe.dart';

enum MediaType {
  photo,
  video,
}

class MediaModel {
  final String id;
  final MediaType type;

  /// Absolute local file paths on the device.
  final String filePath;

  /// Absolute local file path of a generated/available thumbnail.
  /// Can be empty when unknown; UI should fall back to a placeholder.
  final String thumbnailPath;

  final String fileName;

  final String? albumId;
  final String? folderId;

  final int size;

  final int width;
  final int height;

  /// Only meaningful for videos.
  final Duration? duration;

  final DateTime createdAt;
  final DateTime modifiedAt;

  final bool isFavorite;

  /// Soft delete flag used to keep historical references safe.
  final bool isDeleted;

  /// Optional gradient colors for future theming (not required by Phase 4
  /// but kept lightweight and safe for Hive persistence).
  final List<int> gradientArgb;

  /// Parameters for non-destructive photo adjustments
  final EditRecipe? editRecipe;

  /// Absolute, fetchable URL for the original file on the backend
  /// (`MediaRead.file_url`). Null for media that only exists in the
  /// local Hive cache and hasn't been uploaded yet.
  final String? remoteUrl;

  /// Absolute, fetchable URL for the generated thumbnail
  /// (`MediaRead.thumbnail_url`). Null when the backend hasn't produced
  /// one (e.g. videos) or the media is local-only.
  final String? remoteThumbnailUrl;

  /// Server-seeded like count (`MediaRead.like_count`). Used to prime
  /// [MediaLikesCommentsController]'s cache the first time this media is
  /// shown, so the like button doesn't default to 0 until tapped.
  final int likeCount;

  /// Server-seeded "did the current user like this" flag
  /// (`MediaRead.is_liked_by_me`). Same priming purpose as [likeCount].
  final bool isLikedByMe;

  /// Server-seeded comment count (`MediaRead.comment_count`, Task
  /// 21.14/21.15). Used by [MediaThumbBadges] (Task 21.11) to show a
  /// real comment count on grid tiles without a per-tile fetch.
  final int commentCount;

  /// Server-seeded `MediaRead.can_revert` — true once this media has
  /// been destructively overwritten at least once on the backend, so
  /// "Revert to Original" has something to restore. Always false for
  /// local-only media (nothing to revert against).
  final bool canRevert;

  const MediaModel({
    required this.id,
    required this.type,
    required this.filePath,
    required this.thumbnailPath,
    required this.fileName,
    this.albumId,
    this.folderId,
    required this.size,
    required this.width,
    required this.height,
    this.duration,
    required this.createdAt,
    required this.modifiedAt,
    this.isFavorite = false,
    this.isDeleted = false,
    this.gradientArgb = const [
      0xFF7C5CFF,
      0xFFA855F7,
      0xFFEC4899,
    ],
    this.editRecipe,
    this.remoteUrl,
    this.remoteThumbnailUrl,
    this.likeCount = 0,
    this.isLikedByMe = false,
    this.commentCount = 0,
    this.canRevert = false,
  });

  /// Builds a [MediaModel] from a `GET/POST /media` response body
  /// (`MediaRead` in `app/schemas/gallery.py`). There is no local
  /// [filePath]/[thumbnailPath] for API-sourced media until it's been
  /// downloaded into the cache, so those are left empty and callers
  /// should render from [remoteUrl]/[remoteThumbnailUrl] instead.
  factory MediaModel.fromApiJson(Map<String, dynamic> json) {
    final durationMs = json['duration_ms'] as int?;
    return MediaModel(
      id: json['id'] as String,
      type: (json['type'] as String) == 'video' ? MediaType.video : MediaType.photo,
      filePath: '',
      thumbnailPath: '',
      fileName: json['file_name'] as String,
      albumId: json['album_id'] as String?,
      folderId: json['folder_id'] as String?,
      size: json['size_bytes'] as int? ?? 0,
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      duration: durationMs == null ? null : Duration(milliseconds: durationMs),
      createdAt: DateTime.parse(json['created_at'] as String),
      modifiedAt: DateTime.parse(json['updated_at'] as String),
      isFavorite: json['is_favorite'] as bool? ?? false,
      isDeleted: json['is_deleted'] as bool? ?? false,
      editRecipe: json['edit_recipe'] != null
          ? EditRecipe.fromJson(json['edit_recipe'] as Map<String, dynamic>)
          : null,
      remoteUrl: json['file_url'] as String?,
      remoteThumbnailUrl: json['thumbnail_url'] as String?,
      likeCount: json['like_count'] as int? ?? 0,
      isLikedByMe: json['is_liked_by_me'] as bool? ?? false,
      commentCount: json['comment_count'] as int? ?? 0,
      canRevert: json['can_revert'] as bool? ?? false,
    );
  }

  /// Body for `PATCH /media/{id}` (`MediaUpdate`) — move / favorite /
  /// rename / edit-recipe are all optional so only pass what actually
  /// changed.
  Map<String, dynamic> toUpdateJson({
    String? albumId,
    bool clearAlbum = false,
    String? folderId,
    bool clearFolder = false,
    bool? isFavorite,
    String? fileName,
    EditRecipe? editRecipe,
    bool clearEditRecipe = false,
  }) => {
        if (albumId != null) 'album_id': albumId,
        if (clearAlbum) 'clear_album': true,
        if (folderId != null) 'folder_id': folderId,
        if (clearFolder) 'clear_folder': true,
        if (isFavorite != null) 'is_favorite': isFavorite,
        if (fileName != null) 'file_name': fileName,
        if (clearEditRecipe) 'clear_edit_recipe': true,
        if (!clearEditRecipe && editRecipe != null) 'edit_recipe': editRecipe.toJson(),
      };

  /// What to actually render for this item: the local file path when one
  /// exists (Hive-cached / not-yet-uploaded media), otherwise the
  /// backend's `file_url` for API-sourced media. Empty string if neither
  /// is available — callers should fall back to the gradient placeholder.
  String get displayPath => filePath.isNotEmpty ? filePath : (remoteUrl ?? '');

  /// Same idea for the thumbnail: local thumbnail path if present,
  /// otherwise the backend's `thumbnail_url`, otherwise falls back to
  /// [displayPath] itself (full image) since not all media has a
  /// generated thumbnail (e.g. videos).
  String get displayThumbnailPath => thumbnailPath.isNotEmpty
      ? thumbnailPath
      : (remoteThumbnailUrl ?? displayPath);

  /// True if [displayPath] is a fetchable `http(s)://` URL rather than a
  /// local on-device file path.
  bool get isDisplayPathNetwork =>
      displayPath.startsWith('http://') || displayPath.startsWith('https://');

  MediaModel copyWith({
    String? id,
    MediaType? type,
    String? filePath,
    String? thumbnailPath,
    String? fileName,
    String? albumId,
    String? folderId,
    int? size,
    int? width,
    int? height,
    Duration? duration,
    DateTime? createdAt,
    DateTime? modifiedAt,
    bool? isFavorite,
    bool? isDeleted,
    List<int>? gradientArgb,
    EditRecipe? editRecipe,
    String? remoteUrl,
    String? remoteThumbnailUrl,
    int? likeCount,
    bool? isLikedByMe,
    int? commentCount,
    bool? canRevert,
  }) {
    return MediaModel(
      id: id ?? this.id,
      type: type ?? this.type,
      filePath: filePath ?? this.filePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      fileName: fileName ?? this.fileName,
      albumId: albumId ?? this.albumId,
      folderId: folderId ?? this.folderId,
      size: size ?? this.size,
      width: width ?? this.width,
      height: height ?? this.height,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      isDeleted: isDeleted ?? this.isDeleted,
      gradientArgb: gradientArgb ?? this.gradientArgb,
      editRecipe: editRecipe ?? this.editRecipe,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      remoteThumbnailUrl: remoteThumbnailUrl ?? this.remoteThumbnailUrl,
      likeCount: likeCount ?? this.likeCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      commentCount: commentCount ?? this.commentCount,
      canRevert: canRevert ?? this.canRevert,
    );
  }
}