import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/studio_model.dart';
import '../../providers/studio_provider.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/empty_state_card.dart';
import '../../widgets/common/inline_error_banner.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/screen_backdrop.dart';
import 'discover_studios_screen.dart'; // Reuse StudioCard

/// Screen showing bookmarked / favorite studios, sourced from
/// `GET /studios/favorites` via [StudioNotifier.loadFavorites] — not the
/// local Hive-backed directory store.
class FavoriteStudiosScreen extends ConsumerStatefulWidget {
  const FavoriteStudiosScreen({super.key});

  @override
  ConsumerState<FavoriteStudiosScreen> createState() => _FavoriteStudiosScreenState();
}

class _FavoriteStudiosScreenState extends ConsumerState<FavoriteStudiosScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh from the backend every time this screen is opened, so a
    // favorite toggled from the Discover or Studio Profile screens (or
    // another device) is always reflected here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(studioProvider.notifier).loadFavorites();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(studioProvider);
    final favoriteStudios = provider.studios.where((s) => s.isFavorite).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: const CustomAppBar(
        title: 'Favorite Studios',
        showBack: true,
      ),
      body: ScreenBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: kToolbarHeight),
            child: RefreshIndicator(
              onRefresh: () => ref.read(studioProvider.notifier).loadFavorites(),
              child: _buildBody(provider, favoriteStudios),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(StudioNotifier provider, List<StudioModel> favoriteStudios) {
    if (provider.isLoadingFavorites && favoriteStudios.isEmpty) {
      return _scrollableMessage(
        const Center(child: LoadingWidget(message: 'Loading your favorites…')),
      );
    }

    if (provider.favoritesError != null && favoriteStudios.isEmpty) {
      return _scrollableMessage(
        Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: InlineErrorBanner(message: provider.favoritesError!),
          ),
        ),
      );
    }

    if (favoriteStudios.isEmpty) {
      return _scrollableMessage(_buildEmptyState());
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 8, AppSpacing.md, AppSpacing.lg),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      itemCount: favoriteStudios.length,
      itemBuilder: (context, index) {
        final studio = favoriteStudios[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: StudioCard(studio: studio),
        );
      },
    );
  }

  /// Wraps non-list states (loading/error/empty) in a scrollable so
  /// [RefreshIndicator]'s pull-to-refresh gesture still works even when
  /// there's no list content to scroll.
  Widget _scrollableMessage(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            EmptyStateCard(
              icon: Icons.favorite_border_rounded,
              message: 'No Favorite Studios Saved',
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              'Studios you bookmark will appear here for quick access.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.subtitle,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
