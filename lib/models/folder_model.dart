/// Folder entity used by the Albums List screen and the Folder
/// Management flow (list, details, rename, move, settings).
///
/// Folders are used as a filter (e.g. "Weddings") and as counts in album
/// cards. This is kept entirely in-memory (no network/db/files).
class FolderModel {
  final String id;
  final String name;

  /// Number of albums directly filed under this folder. Treated as a
  /// cache: [FolderListController.recomputeAlbumCounts] keeps it in
  /// sync with the real Album↔Folder links after every album mutation,
  /// so screens can keep reading it as a plain field.
  final int albumCount;

  /// Optional visual hint for pills / badges.
  final List<int> gradientArgb;

  /// Null when the folder lives at the root level. Otherwise the id of
  /// the folder it has been moved/nested into (Move Folder screen).
  final String? parentId;

  /// Folder Settings toggle — hides the folder (and its albums) from the
  /// read-only Client Gallery once that view ships.
  final bool isHidden;

  /// User favorite toggle, mirroring Album favorites.
  final bool isFavorite;

  /// When the folder was created — used for Folder Statistics and for
  /// "recent" sorting.
  final DateTime createdAt;

  FolderModel({
    required this.id,
    required this.name,
    required this.albumCount,
    required this.gradientArgb,
    this.parentId,
    this.isHidden = false,
    this.isFavorite = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Builds a [FolderModel] from a `GET/POST/PATCH /folders` response
  /// body (`FolderRead` in `app/schemas/gallery.py`).
  factory FolderModel.fromApiJson(Map<String, dynamic> json) {
    return FolderModel(
      id: json['id'] as String,
      name: json['name'] as String,
      albumCount: json['album_count'] as int? ?? 0,
      gradientArgb: (json['gradient_argb'] as List<dynamic>?)?.cast<int>() ?? const [],
      parentId: json['parent_id'] as String?,
      isHidden: json['is_hidden'] as bool? ?? false,
      isFavorite: json['is_favorite'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Body for `POST /folders` (`FolderCreate`).
  Map<String, dynamic> toCreateJson() => {
        'name': name,
        if (parentId != null) 'parent_id': parentId,
        if (gradientArgb.isNotEmpty) 'gradient_argb': gradientArgb,
      };

  /// Body for `PATCH /folders/{id}` (`FolderUpdate`). See
  /// [AlbumModel.toUpdateJson] for why `clear_parent` is explicit.
  Map<String, dynamic> toUpdateJson({bool clearParent = false}) => {
        'name': name,
        'parent_id': parentId,
        'clear_parent': clearParent,
        'is_hidden': isHidden,
        'is_favorite': isFavorite,
        'gradient_argb': gradientArgb,
      };

  List<FolderGradientColor> gradientColors() {
    return gradientArgb.map((a) => FolderGradientColor(a)).toList();
  }

  /// Deserializes from a plain JSON map (Hive-local store format).
  factory FolderModel.fromJson(Map<String, dynamic> json) {
    return FolderModel(
      id: json['id'] as String,
      name: json['name'] as String,
      albumCount: json['albumCount'] as int? ?? 0,
      gradientArgb: (json['gradientArgb'] as List<dynamic>?)?.cast<int>() ?? const [],
      parentId: json['parentId'] as String?,
      isHidden: json['isHidden'] as bool? ?? false,
      isFavorite: json['isFavorite'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Serializes to a plain JSON map (Hive-local store format).
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'albumCount': albumCount,
        'gradientArgb': gradientArgb,
        'parentId': parentId,
        'isHidden': isHidden,
        'isFavorite': isFavorite,
        'createdAt': createdAt.toIso8601String(),
      };

  FolderModel copyWith({
    String? id,
    String? name,
    int? albumCount,
    List<int>? gradientArgb,
    String? parentId,
    bool clearParent = false,
    bool? isHidden,
    bool? isFavorite,
    DateTime? createdAt,
  }) {
    return FolderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      albumCount: albumCount ?? this.albumCount,
      gradientArgb: gradientArgb ?? this.gradientArgb,
      parentId: clearParent ? null : (parentId ?? this.parentId),
      isHidden: isHidden ?? this.isHidden,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class FolderGradientColor {
  final int value;
  const FolderGradientColor(this.value);
}
