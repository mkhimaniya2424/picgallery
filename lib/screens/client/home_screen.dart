import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'main_nav_screen.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/connected_albums_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/alerts_provider.dart';

import '../../widgets/client/home_sections.dart';
import '../../widgets/common/empty_state_card.dart';

/// Upgraded Client Home Dashboard.
///
/// Composed of independent section widgets from [home_sections.dart],
/// each driven exclusively by existing provider data. Every section
/// supports loading, empty, and data states. All existing providers,
/// models, theme tokens, and routes are reused as-is.
///
/// Collections and Recent Downloads were removed from this screen —
/// both `GET /collections` and `GET /download-history` are studio-only
/// routes (`get_current_studio_user`) with no client-facing equivalent
/// yet, so they always 403 for a client account. Re-add once a
/// client-scoped backend route exists for either.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final connectedState = ref.watch(connectedAlbumsProvider);

    final userName =
        settings.photographerName.isNotEmpty ? settings.photographerName : null;

    final favoriteGalleries = connectedState.favoriteAlbums;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await ref.read(connectedAlbumsProvider.notifier).refresh();
        await ref.read(alertsProvider).load();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Welcome Header ──────────────────────────────────
            _buildHeroHeader(context, userName),
            const SizedBox(height: AppSpacing.lg),

            // ── 2. Quick Actions ───────────────────────────────────
            const QuickActionRow(),
            const SizedBox(height: AppSpacing.xl),

            // ── 3. Connected Studios ──────────────────────────────
            const ConnectedStudiosSection(),
            const SizedBox(height: AppSpacing.xl),

            // ── 4. Continue Viewing (Recent Galleries) ────────────
            const ContinueViewingSection(),
            const SizedBox(height: AppSpacing.xl),

            // ── 5. Recently Viewed ────────────────────────────────
            const RecentlyViewedSection(),
            const SizedBox(height: AppSpacing.xl),

            // ── 6. Trending Galleries ─────────────────────────────
            // "Recommended" (Task 21.19) was dropped here — its
            // non-favorite/recency sort was redundant with Recently
            // Viewed/Continue Viewing above, since `is_favorite` is a
            // studio-set flag a client rarely sees toggled. Trending's
            // size-based sort stayed since it's the only distinct axis
            // among the three.
            const TrendingGalleriesSection(),
            const SizedBox(height: AppSpacing.xl),

            // ── 7. Saved Galleries (Favorites) ────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: 'Saved Galleries',
                    onSeeAll: null,
                  ),
                  if (connectedState.isLoading && connectedState.albums.isEmpty)
                    const SectionLoadingLine()
                  else if (favoriteGalleries.isEmpty)
                    const EmptyStateCard(
                      icon: Icons.bookmark_border_rounded,
                      message: 'No saved galleries yet.',
                    )
                  else
                    GalleryGrid(albums: favoriteGalleries),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── 8. Recent Activity ──────────────────────────────
            const RecentActivitySection(),
            const SizedBox(height: AppSpacing.xl),

            // ── 9. Upcoming Shared Galleries ────────────────────
            const SharedGalleriesSection(),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  /// Full-bleed gradient hero: greeting + notification bell + avatar on
  /// top, a tappable "search" field beneath. Shows user name when set.
  Widget _buildHeroHeader(BuildContext context, String? userName) {
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        topInset + AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadius.lg),
          bottomRight: Radius.circular(AppRadius.lg),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _HeroIconButton(
                icon: Icons.menu_rounded,
                onTap: () {
                  context.findAncestorStateOfType<MainNavScreenState>()?.openDrawer();
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      userName != null ? 'Welcome, $userName' : 'Welcome back',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              _HeroIconButton(
                icon: Icons.notifications_none_rounded,
                // Same fix as RecentActivitySection.onSeeAll below: this
                // used to push AppRoutes.notifications (the Studio's
                // NotificationsScreen), which isn't the client's screen
                // at all. Switch to the Alerts bottom-nav tab instead.
                onTap: () => context
                    .findAncestorStateOfType<MainNavScreenState>()
                    ?.goToTab(2),
              ),
              const SizedBox(width: 10),
              InkWell(
                borderRadius: BorderRadius.circular(100),
                onTap: () => context
                    .findAncestorStateOfType<MainNavScreenState>()
                    ?.goToTab(3),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.discoverStudios),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded,
                        color: Colors.white.withValues(alpha: 0.85), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Search studios & galleries',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Round glass icon button styled for use on top of the gradient hero.
class _HeroIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeroIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 19),
      ),
    );
  }
}