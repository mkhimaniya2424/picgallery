import 'package:flutter/material.dart';

/// Data shapes for Global Search. Mirrors the same "type definitions
/// only" pattern as `admin_dashboard_data.dart` — actual dummy content
/// lives in `SearchRepository`, never hardcoded in the UI layer.

enum SearchResultType { album, photo, video, folder }

extension SearchResultTypeX on SearchResultType {
  String get label {
    switch (this) {
      case SearchResultType.album:
        return 'Albums';
      case SearchResultType.photo:
        return 'Photos';
      case SearchResultType.video:
        return 'Videos';
      case SearchResultType.folder:
        return 'Folders';
    }
  }

  IconData get icon {
    switch (this) {
      case SearchResultType.album:
        return Icons.photo_album_rounded;
      case SearchResultType.photo:
        return Icons.image_rounded;
      case SearchResultType.video:
        return Icons.videocam_rounded;
      case SearchResultType.folder:
        return Icons.folder_rounded;
    }
  }

  List<Color> get gradient {
    switch (this) {
      case SearchResultType.album:
        return const [Color(0xFF7C5CFF), Color(0xFFA855F7)];
      case SearchResultType.photo:
        return const [Color(0xFFA855F7), Color(0xFFEC4899)];
      case SearchResultType.video:
        return const [Color(0xFFEC4899), Color(0xFFF472B6)];
      case SearchResultType.folder:
        return const [Color(0xFF22C55E), Color(0xFF7C5CFF)];
    }
  }
}

class SearchResultItem {
  final String id;
  final SearchResultType type;
  final String title;
  final String subtitle;

  const SearchResultItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
  });
}
