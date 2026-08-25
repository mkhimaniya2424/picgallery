/// Represents a like on a media item, as returned by the backend API
/// (`MediaLikeRead` in `app/schemas/gallery.py`).
class MediaLike {
  final String id;
  final String mediaId;
  final String userId;
  final String userFullName;
  final DateTime createdAt;

  const MediaLike({
    required this.id,
    required this.mediaId,
    required this.userId,
    this.userFullName = '',
    required this.createdAt,
  });

  MediaLike copyWith({
    String? id,
    String? mediaId,
    String? userId,
    String? userFullName,
    DateTime? createdAt,
  }) {
    return MediaLike(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      userId: userId ?? this.userId,
      userFullName: userFullName ?? this.userFullName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'mediaId': mediaId,
        'userId': userId,
        'userFullName': userFullName,
        'createdAt': createdAt.toIso8601String(),
      };

  static MediaLike fromJson(Map<String, dynamic> json) {
    final createdAtStr = json['createdAt'] as String? ?? '';
    final createdAt = DateTime.tryParse(createdAtStr) ??
        DateTime.fromMillisecondsSinceEpoch(0);

    return MediaLike(
      id: json['id'] as String? ?? '',
      mediaId: json['mediaId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userFullName: json['userFullName'] as String? ?? '',
      createdAt: createdAt,
    );
  }

  /// Parses from the backend's `MediaLikeRead` response (snake_case keys).
  factory MediaLike.fromApiJson(Map<String, dynamic> json) {
    return MediaLike(
      id: json['id'] as String,
      mediaId: json['media_id'] as String,
      userId: json['user_id'] as String,
      userFullName: json['user_full_name'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

