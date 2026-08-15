/// A single downloaded media event.
///
/// API-backed: loaded from `GET /download-history` (`DownloadEventRead`
/// in `app/schemas/gallery.py`), with a Hive mirror kept only as an
/// offline read cache (same pattern as `CachingMediaRepository`).
class DownloadHistoryModel {
  final String id;

  /// Backend `Media.id` this event was logged against (`media_id` in
  /// `DownloadEventRead`). Used to look up the media in `mediaProvider`
  /// so the row can show a real thumbnail and open the full viewer.
  /// Null for rows where the backend itself has no media reference
  /// (e.g. the source media was hard-deleted after the download).
  final String? mediaId;

  /// Filename (with extension) shown in the history list.
  final String fileName;

  /// Absolute local path to a generated thumbnail (if available).
  /// When empty/unknown, UI can fall back to a placeholder. The backend
  /// doesn't track this (it's a server-side event log, not a file
  /// index), so it's only ever populated for a download this device
  /// just performed in this session — API-sourced rows always have
  /// this empty and fall back to the placeholder, which the existing
  /// UI already handles.
  final String thumbnailPath;

  /// Network thumbnail/file URL resolved server-side from the still-
  /// live `Media` row (`DownloadEventRead.thumbnail_url`/`file_url`).
  /// Unlike [thumbnailPath], this is populated for every API-sourced
  /// row and works regardless of whether the media is in the current
  /// account's own media list — the only thing that let a *studio's*
  /// row show a real thumbnail before, and never worked for a client
  /// account at all, since a client's media list never contains
  /// another studio's media.
  final String? thumbnailUrl;
  final String? fileUrl;

  /// Absolute local path to the original file (optional; used for share/open).
  /// Same local-only caveat as [thumbnailPath].
  final String filePath;

  /// Bytes
  final int size;

  /// Photo/video
  final MediaType mediaType;

  /// Download date/time
  final DateTime downloadedAt;

  const DownloadHistoryModel({
    required this.id,
    this.mediaId,
    required this.fileName,
    required this.thumbnailPath,
    this.thumbnailUrl,
    this.fileUrl,
    required this.filePath,
    required this.size,
    required this.mediaType,
    required this.downloadedAt,
  });

  /// Builds from a `GET /download-history` list item (`DownloadEventRead`).
  /// There's no on-device file path in a server-side event log, so
  /// [filePath]/[thumbnailPath] are left empty — the UI already falls
  /// back to a placeholder icon when they're blank.
  factory DownloadHistoryModel.fromApiJson(Map<String, dynamic> json) {
    final mediaTypeStr = json['media_type'] as String? ?? MediaType.photo.name;
    final mediaType = MediaType.values.firstWhere(
      (t) => t.name == mediaTypeStr,
      orElse: () => MediaType.photo,
    );

    return DownloadHistoryModel(
      id: json['id'] as String,
      mediaId: json['media_id'] as String?,
      fileName: json['file_name'] as String? ?? '',
      thumbnailPath: '',
      thumbnailUrl: json['thumbnail_url'] as String?,
      fileUrl: json['file_url'] as String?,
      filePath: '',
      size: json['size_bytes'] as int? ?? 0,
      mediaType: mediaType,
      downloadedAt: DateTime.parse(json['downloaded_at'] as String),
    );
  }

  DownloadHistoryModel copyWith({
    String? id,
    String? mediaId,
    String? fileName,
    String? thumbnailPath,
    String? thumbnailUrl,
    String? fileUrl,
    String? filePath,
    int? size,
    MediaType? mediaType,
    DateTime? downloadedAt,
  }) {
    return DownloadHistoryModel(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      fileName: fileName ?? this.fileName,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      fileUrl: fileUrl ?? this.fileUrl,
      filePath: filePath ?? this.filePath,
      size: size ?? this.size,
      mediaType: mediaType ?? this.mediaType,
      downloadedAt: downloadedAt ?? this.downloadedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mediaId': mediaId,
      'fileName': fileName,
      'thumbnailPath': thumbnailPath,
      'thumbnailUrl': thumbnailUrl,
      'fileUrl': fileUrl,
      'filePath': filePath,
      'size': size,
      'mediaType': mediaType.name,
      'downloadedAt': downloadedAt.toIso8601String(),
    };
  }

  static DownloadHistoryModel fromJson(Map<String, dynamic> json) {
    final mediaTypeStr = json['mediaType'] as String? ?? MediaType.photo.name;
    final mediaType = MediaType.values.firstWhere(
      (t) => t.name == mediaTypeStr,
      orElse: () => MediaType.photo,
    );

    return DownloadHistoryModel(
      id: json['id'] as String,
      mediaId: json['mediaId'] as String?,
      fileName: json['fileName'] as String? ?? '',
      thumbnailPath: json['thumbnailPath'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      fileUrl: json['fileUrl'] as String?,
      filePath: json['filePath'] as String? ?? '',
      size: json['size'] as int? ?? 0,
      mediaType: mediaType,
      downloadedAt: DateTime.tryParse(json['downloadedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Reuse the same enum names used by media models.
/// Keeping it local to this module avoids coupling to other models.
enum MediaType {
  photo,
  video,
}