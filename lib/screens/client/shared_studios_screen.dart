import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/client_gallery_provider.dart';
import '../../repositories/client_gallery_repository.dart';
import '../../widgets/cards/glass_card.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/empty_state_card.dart';
import '../../widgets/common/inline_error_banner.dart';
import '../../widgets/common/loading_widget.dart';

/// Full-screen list of studios that currently have ≥1 active share
/// with the current client — reached from the "Shared With You" section
/// header on [HomeScreen] or when the client taps "See all".
///
/// Tapping a studio card drills into [StudioSharedFoldersScreen] for that
/// studio. Empty state is shown when no studio has shared anything yet.
///
/// Thin Scaffold wrapper around [SharedStudiosListView] — the pushed
/// (has-a-back-button) presentation. The bottom-nav Gallery tab
/// ([GalleryScreen]) embeds the same list view with its own tab chrome
/// instead of duplicating the loading/error/empty/list logic here.
class SharedStudiosScreen extends StatelessWidget {
  const SharedStudiosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      
      appBar: CustomAppBar(title: 'Shared With You', showBack: true),
      body: SafeArea(child: SharedStudiosListView()),
    );
  }
}

/// The actual studios list — loading/error/empty states plus the
/// [SharedStudioCard] list — extracted so it can be embedded both inside
/// [SharedStudiosScreen] (pushed, its own app bar) and directly as the
/// bottom-nav Gallery tab body ([GalleryScreen], tab chrome instead).
class SharedStudiosListView extends ConsumerStatefulWidget {
  const SharedStudiosListView({super.key});

  @override
  ConsumerState<SharedStudiosListView> createState() => _SharedStudiosListViewState();
}

class _SharedStudiosListViewState extends ConsumerState<SharedStudiosListView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(clientGalleryProvider.notifier).loadStudios();
    });
  }

  Future<void> _refresh() async {
    await ref.read(clientGalleryProvider.notifier).loadStudios();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clientGalleryProvider);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: _buildBody(state),
    );
  }

  Widget _buildBody(ClientGalleryState state) {
    if (state.isLoadingStudios && state.studios.isEmpty) {
      return _scrollable(
        const Center(child: LoadingWidget(message: 'Loading shared galleries…')),
      );
    }

    if (state.studiosError != null && state.studios.isEmpty) {
      return _scrollable(
        Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: InlineErrorBanner(message: state.studiosError!),
          ),
        ),
      );
    }

    if (state.studios.isEmpty) {
      return _scrollable(
        const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                EmptyStateCard(
                  icon: Icons.ios_share_rounded,
                  message: 'No Shared Galleries Yet',
                ),
                SizedBox(height: AppSpacing.md),
                Text(
                  'Studios you connect with will share galleries here.',
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
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
      itemCount: state.studios.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => SharedStudioCard(studio: state.studios[index]),
    );
  }

  Widget _scrollable(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable card — also imported by [home_sections.dart] via a show import.
// ─────────────────────────────────────────────────────────────────────────────

class SharedStudioCard extends StatelessWidget {
  final SharedStudioModel studio;

  const SharedStudioCard({super.key, required this.studio});

  @override
  Widget build(BuildContext context) {
    // Task 21.17: swapped the flat `AppColors.darkSurface` box for
    // `GlassCard` — same frosted-panel language `discover_studios_screen.dart`
    // uses for its studio cards, rather than a one-off dark card that
    // doesn't match the rest of the client-facing screens.
    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: AppRadius.md,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => Navigator.of(context).pushNamed(
          AppRoutes.studioSharedFolders,
          arguments: {'studioId': studio.id},
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Studio logo or avatar placeholder
              _StudioAvatar(logoUrl: studio.logoUrl, name: studio.name),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studio.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${studio.sharedCount} shared ${studio.sharedCount == 1 ? 'gallery' : 'galleries'}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.subtitle,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.subtitle,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioAvatar extends StatelessWidget {
  final String? logoUrl;
  final String name;

  const _StudioAvatar({this.logoUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    if (logoUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Image.network(
          logoUrl!,
          width: 46,
          height: 46,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: AppColors.buttonGradient,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'S',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}