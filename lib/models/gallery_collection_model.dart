/// A collection is an ordered list of *album* ids — matching the backend
/// (`app/models/gallery.py`'s `GalleryCollection`/`CollectionItem`,
/// `app/api/routes/collections.py`), where `CollectionItem.album_id` is a
/// real FK into the `Album` table. A gallery/album itself is represented
/// by the existing [AlbumModel] elsewhere in the app.
///
/// e.g. "2024 Weddings" pulling together several unrelated albums.
class GalleryCollectionModel {
  final String id;
  final String name;

  /// Ordered album ids.
  final List<String> galleryIds;

  final int displayOrder;

  final DateTime createdAt;
  final DateTime updatedAt;

  const GalleryCollectionModel({
    required this.id,
    required this.name,
    required this.galleryIds,
    this.displayOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  GalleryCollectionModel copyWith({
    String? id,
    String? name,
    List<String>? galleryIds,
    int? displayOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GalleryCollectionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      galleryIds: galleryIds ?? this.galleryIds,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// API JSON (snake_case)
  factory GalleryCollectionModel.fromApiJson(Map<String, dynamic> json) {
    return GalleryCollectionModel(
      id: json['id'] as String,
      name: json['name'] as String,
      galleryIds: (json['gallery_ids'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      displayOrder: json['display_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Local JSON (used by Hive cache)
  factory GalleryCollectionModel.fromJson(Map<String, dynamic> json) {
    return GalleryCollectionModel(
      id: json['id'] as String,
      name: json['name'] as String,
      galleryIds: (json['galleryIds'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      displayOrder: json['displayOrder'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Local JSON (used by Hive cache)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'galleryIds': galleryIds,
      'displayOrder': displayOrder,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// API JSON (snake_case)
  Map<String, dynamic> toApiJson() {
    return {
      'id': id,
      'name': name,
      'gallery_ids': galleryIds,
      'display_order': displayOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}