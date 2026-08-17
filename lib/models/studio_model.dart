enum StudioConnectionStatus {
  notConnected,
  pending,
  connected,
}

class StudioModel {
  final String id;
  final String name;
  final String about;
  final String logoUrl;
  final String coverUrl;
  final List<String> categories;
  final double rating;
  final int reviewCount;
  final String location;
  final List<String> galleryUrls;
  final StudioConnectionStatus connectionStatus;
  final String email;
  final String website;

  /// Client-side favorite/bookmark toggle. Persisted server-side via
  /// `POST/DELETE /studios/{id}/favorite` — see `ApiStudioRepository`.
  final bool isFavorite;

  /// Password hash used only in local/admin editing context.
  final String passwordHash;

  StudioModel({
    required this.id,
    required this.name,
    required this.about,
    required this.logoUrl,
    required this.coverUrl,
    required this.categories,
    required this.rating,
    required this.reviewCount,
    required this.location,
    required this.galleryUrls,
    required this.connectionStatus,
    required this.email,
    required this.website,
    this.isFavorite = false,
    this.passwordHash = '',
  });

  /// Builds a [StudioModel] from the nested `studio` object inside a
  /// `GET /studios/favorites` row (`FavoriteStudioRead` in
  /// `app/schemas/studio.py`). That endpoint only returns the public,
  /// non-owner-facing subset of a studio's profile (`StudioSummary`) —
  /// no `rating`/`reviewCount`/contact details, since those aren't
  /// tracked on the backend yet — so this factory fills those in with
  /// sensible empty defaults rather than fabricating data.
  /// `coverUrl`/`galleryUrls` *are* real backend fields now (Showcase
  /// Portfolio) and are parsed from the response. Always sets
  /// [isFavorite] to `true`, since every row this endpoint returns is,
  /// by definition, a favorited studio.
  factory StudioModel.fromFavoriteApiJson(Map<String, dynamic> json) {
    final location = [json['city'], json['state']]
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .join(', ');

    return StudioModel(
      id: json['id'] as String,
      name: (json['studio_name'] as String?) ?? 'Unnamed Studio',
      about: (json['bio'] as String?) ?? '',
      logoUrl: (json['avatar_url'] as String?) ?? '',
      coverUrl: (json['cover_image_url'] as String?) ?? '',
      categories: (json['specializations'] as List<dynamic>?)?.cast<String>() ?? const [],
      rating: 0,
      reviewCount: 0,
      location: location,
      galleryUrls: (json['gallery_urls'] as List<dynamic>?)?.cast<String>() ?? const [],
      connectionStatus: StudioConnectionStatus.notConnected,
      email: '',
      website: '',
      isFavorite: true,
    );
  }

  /// Builds a [StudioModel] from one row of `GET /studios`
  /// (`StudioDirectoryItem` in `app/schemas/studio.py`) — backs the
  /// Discover Studios screen. Like [fromFavoriteApiJson], the backend
  /// only tracks the public `StudioSummary` subset, so
  /// rating/reviewCount/contact details stay at empty defaults rather
  /// than being fabricated; `coverUrl`/`galleryUrls` are parsed from
  /// the response.
  factory StudioModel.fromDirectoryApiJson(Map<String, dynamic> json) {
    final location = [json['city'], json['state']]
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .join(', ');

    return StudioModel(
      id: json['id'] as String,
      name: (json['studio_name'] as String?) ?? 'Unnamed Studio',
      about: (json['bio'] as String?) ?? '',
      logoUrl: (json['avatar_url'] as String?) ?? '',
      coverUrl: (json['cover_image_url'] as String?) ?? '',
      categories: (json['specializations'] as List<dynamic>?)?.cast<String>() ?? const [],
      rating: 0,
      reviewCount: 0,
      location: location,
      galleryUrls: (json['gallery_urls'] as List<dynamic>?)?.cast<String>() ?? const [],
      connectionStatus: StudioConnectionStatus.values.firstWhere(
        (e) => e.name == json['connection_status'],
        orElse: () => StudioConnectionStatus.notConnected,
      ),
      email: '',
      website: '',
      isFavorite: json['is_favorite'] as bool? ?? false,
    );
  }

  /// Local (Hive) persistence round-trip — used by [StudioLocalStore]
  /// for the offline/demo directory cache. Distinct from
  /// [fromFavoriteApiJson]/[fromDirectoryApiJson], which parse the
  /// real backend's response shapes instead.
  factory StudioModel.fromJson(Map<String, dynamic> json) {
    return StudioModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      about: json['about'] as String? ?? '',
      logoUrl: json['logoUrl'] as String? ?? '',
      coverUrl: json['coverUrl'] as String? ?? '',
      categories: (json['categories'] as List<dynamic>?)?.cast<String>() ?? const [],
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: json['reviewCount'] as int? ?? 0,
      location: json['location'] as String? ?? '',
      galleryUrls: (json['galleryUrls'] as List<dynamic>?)?.cast<String>() ?? const [],
      connectionStatus: StudioConnectionStatus.values.firstWhere(
        (e) => e.name == json['connectionStatus'],
        orElse: () => StudioConnectionStatus.notConnected,
      ),
      email: json['email'] as String? ?? '',
      website: json['website'] as String? ?? '',
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'about': about,
        'logoUrl': logoUrl,
        'coverUrl': coverUrl,
        'categories': categories,
        'rating': rating,
        'reviewCount': reviewCount,
        'location': location,
        'galleryUrls': galleryUrls,
        'connectionStatus': connectionStatus.name,
        'email': email,
        'website': website,
        'isFavorite': isFavorite,
      };

  StudioModel copyWith({
    String? id,
    String? name,
    String? about,
    String? logoUrl,
    String? coverUrl,
    List<String>? categories,
    double? rating,
    int? reviewCount,
    String? location,
    List<String>? galleryUrls,
    StudioConnectionStatus? connectionStatus,
    String? email,
    String? website,
    bool? isFavorite,
  }) {
    return StudioModel(
      id: id ?? this.id,
      name: name ?? this.name,
      about: about ?? this.about,
      logoUrl: logoUrl ?? this.logoUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      categories: categories ?? this.categories,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      location: location ?? this.location,
      galleryUrls: galleryUrls ?? this.galleryUrls,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      email: email ?? this.email,
      website: website ?? this.website,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}