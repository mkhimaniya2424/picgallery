/// Local representation of a comment for a media item.
///
/// Designed for frontend-only persistence but structured so it can later
/// be mapped to backend models.
class MediaComment {
  final String id;
  final String mediaId;
  final String userId;

  /// Parent comment id when this is a reply. `null` means top-level.
  final String? parentId;

  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Resolved on read from the API: the comment author's display name.
  final String userFullName;

  const MediaComment({
    required this.id,
    required this.mediaId,
    required this.userId,
    this.parentId,
    required this.text,
    required this.createdAt,
    DateTime? updatedAt,
    this.userFullName = '',
  }) : updatedAt = updatedAt ?? createdAt;

  MediaComment copyWith({
    String? id,
    String? mediaId,
    String? userId,
    String? parentId,
    String? text,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userFullName,
  }) {
    return MediaComment(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      userId: userId ?? this.userId,
      parentId: parentId ?? this.parentId,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userFullName: userFullName ?? this.userFullName,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'mediaId': mediaId,
        'userId': userId,
        'parentId': parentId,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'userFullName': userFullName,
      };

  static MediaComment fromJson(Map<String, dynamic> json) {
    final createdAtStr = json['createdAt'] as String? ?? '';
    final createdAt = DateTime.tryParse(createdAtStr) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final updatedAtStr = json['updatedAt'] as String? ?? '';
    final updatedAt = DateTime.tryParse(updatedAtStr) ??
        DateTime.fromMillisecondsSinceEpoch(0);

    return MediaComment(
      id: json['id'] as String? ?? '',
      mediaId: json['mediaId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      parentId: json['parentId'] as String?,
      text: json['text'] as String? ?? '',
      createdAt: createdAt,
      updatedAt: updatedAt,
      userFullName: json['userFullName'] as String? ?? '',
    );
  }

  /// Parses from the backend's `MediaCommentRead` response (snake_case keys).
  factory MediaComment.fromApiJson(Map<String, dynamic> json) {
    return MediaComment(
      id: json['id'] as String,
      mediaId: json['media_id'] as String,
      userId: json['user_id'] as String,
      parentId: json['parent_id'] as String?,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.parse(json['created_at'] as String),
      userFullName: json['user_full_name'] as String? ?? '',
    );
  }
}

