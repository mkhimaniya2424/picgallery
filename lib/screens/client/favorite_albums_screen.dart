import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/connected_albums_provider.dart';
import '../../widgets/client/home_sections.dart' show GalleryGrid;
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/empty_state_card.dart';

/// Full-screen "see all" destination for Home's "Saved Galleries"
/// section — every album a studio has flagged as a favorite, across
/// every studio the client is connected to (`connectedAlbumsProvider`,
/// same data source the Home section itself uses).
///
/// Distinct from [ClientSavedGalleriesScreen] (`client_saved_galleries_screen.dart`),
/// which is the "Favorites" quick action's destination showing
/// individually *liked photos*, not favorited *albums* — two different
/// signals that happened to share a name before this split.
class FavoriteAlbumsScreen extends ConsumerWidget {
  const FavoriteAlbumsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectedState = ref.watch(connectedAlbumsProvider);
    final favorites = connectedState.favoriteAlbums;
    final isLoading = connectedState.isLoading && connectedState.albums.isEmpty;

    return Scaffold(
      
      appBar: const CustomAppBar(title: 'Saved Galleries'),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(connectedAlbumsProvider.notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              : favorites.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: EmptyStateCard(
                        icon: Icons.bookmark_border_rounded,
                        message: 'No saved galleries yet.',
                      ),
                    )
                  : GalleryGrid(albums: favorites, maxItems: favorites.length),
        ),
      ),
    );
  }
}