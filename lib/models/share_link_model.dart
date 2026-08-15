class GalleryShareLink {
  final String id;
  final String albumId;
  final bool isPublic;
  final String? password;
  final DateTime? expiryDate;
  final bool allowDownload;
  final bool showWatermark;
  final bool revoked;

  // Analytics
  final int viewsCount;
  final int downloadsCount;

  final DateTime createdAt;

  GalleryShareLink({
    required this.id,
    required this.albumId,
    required this.isPublic,
    this.password,
    this.expiryDate,
    this.allowDownload = true,
    this.showWatermark = false,
    this.revoked = false,
    this.viewsCount = 0,
    this.downloadsCount = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  bool get isActive => !revoked && !isExpired;

  GalleryShareLink copyWith({
    String? id,
    String? albumId,
    bool? isPublic,
    String? password,
    bool clearPassword = false,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
    bool? allowDownload,
    bool? showWatermark,
    bool? revoked,
    int? viewsCount,
    int? downloadsCount,
    DateTime? createdAt,
  }) {
    return GalleryShareLink(
      id: id ?? this.id,
      albumId: albumId ?? this.albumId,
      isPublic: isPublic ?? this.isPublic,
      password: clearPassword ? null : (password ?? this.password),
      expiryDate: clearExpiryDate ? null : (expiryDate ?? this.expiryDate),
      allowDownload: allowDownload ?? this.allowDownload,
      showWatermark: showWatermark ?? this.showWatermark,
      revoked: revoked ?? this.revoked,
      viewsCount: viewsCount ?? this.viewsCount,
      downloadsCount: downloadsCount ?? this.downloadsCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'albumId': albumId,
      'isPublic': isPublic,
      'password': password,
      'expiryDate': expiryDate?.toIso8601String(),
      'allowDownload': allowDownload,
      'showWatermark': showWatermark,
      'revoked': revoked,
      'viewsCount': viewsCount,
      'downloadsCount': downloadsCount,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory GalleryShareLink.fromJson(Map<String, dynamic> json) {
    return GalleryShareLink(
      id: json['id'] as String,
      albumId: json['albumId'] as String,
      isPublic: json['isPublic'] as bool? ?? true,
      password: json['password'] as String?,
      expiryDate: json['expiryDate'] != null
          ? DateTime.tryParse(json['expiryDate'] as String)
          : null,
      allowDownload: json['allowDownload'] as bool? ?? true,
      showWatermark: json['showWatermark'] as bool? ?? false,
      revoked: json['revoked'] as bool? ?? false,
      viewsCount: json['viewsCount'] as int? ?? 0,
      downloadsCount: json['downloadsCount'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}
