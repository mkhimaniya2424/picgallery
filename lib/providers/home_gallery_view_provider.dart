import 'package:flutter_riverpod/flutter_riverpod.dart';

enum HomeGalleryViewMode { carousel, grid }

/// Drives the list<->grid toggle for Home's Continue Viewing / Recently
/// Viewed / Recommended / Trending sections. One shared switch for all
/// four sections (matches how they already share `connectedAlbumsProvider`
/// as a single data source) rather than a per-section toggle.
final homeGalleryViewModeProvider =
    NotifierProvider<HomeGalleryViewModeNotifier, HomeGalleryViewMode>(
  HomeGalleryViewModeNotifier.new,
);

class HomeGalleryViewModeNotifier extends Notifier<HomeGalleryViewMode> {
  @override
  HomeGalleryViewMode build() => HomeGalleryViewMode.carousel;

  void toggle() {
    state = state == HomeGalleryViewMode.carousel
        ? HomeGalleryViewMode.grid
        : HomeGalleryViewMode.carousel;
  }
}
