import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routes/app_routes.dart';
import '../../models/media_model.dart';
import '../../models/share_link_model.dart';
import '../../providers/share_link_provider.dart';
import '../media/image_viewer_screen.dart';
import '../media/video_player_screen.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/empty_state_card.dart';
import '../../widgets/cards/glass_card.dart';
import '../../widgets/buttons/gradient_button.dart';
import '../../widgets/inputs/custom_text_field.dart';

/// A guest's view of a shared album — reached either via a
/// `picgallery://shared/{token}` deep link (real client scanning the
/// studio's QR/link) or "Preview Client View" from `ShareSettingsScreen`.
///
/// Unlike the old version of this screen, [token] resolves against the
/// real public `/public/share-links/{token}` API
/// (`PublicGalleryController`) — no account, no auth, and no dependency
/// on `albumProvider`/`mediaProvider` (which only ever hold the
/// *current* user's own owner-scoped data and would be empty or 403 for
/// an unauthenticated guest, or for a client viewing a studio they
/// don't own).
class SharedGalleryScreen extends ConsumerStatefulWidget {
  final String token;

  const SharedGalleryScreen({super.key, required this.token});

  @override
  ConsumerState<SharedGalleryScreen> createState() => _SharedGalleryScreenState();
}

class _SharedGalleryScreenState extends ConsumerState<SharedGalleryScreen> {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePasscode = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _submitPasscode() {
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(publicGalleryProvider(widget.token).notifier)
        .unlock(password: _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(publicGalleryProvider(widget.token));

    switch (controller.status) {
      case PublicGalleryStatus.loading:
        return const Scaffold(
          appBar: CustomAppBar(title: 'Shared Gallery', showBack: true),
          body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
        );

      case PublicGalleryStatus.notFound:
        return const Scaffold(
          appBar: CustomAppBar(title: 'Shared Gallery', showBack: true),
          body: Center(
            child: EmptyStateCard(
              icon: Icons.search_off_rounded,
              message: 'This shared link does not exist.',
            ),
          ),
        );

      case PublicGalleryStatus.revoked:
        return const Scaffold(
          appBar: CustomAppBar(title: 'Shared Gallery', showBack: true),
          body: Center(
            child: EmptyStateCard(
              icon: Icons.link_off_rounded,
              message: 'This shared link has been revoked by the photographer.',
            ),
          ),
        );

      case PublicGalleryStatus.expired:
        return const Scaffold(
          appBar: CustomAppBar(title: 'Shared Gallery', showBack: true),
          body: Center(
            child: EmptyStateCard(
              icon: Icons.lock_clock_outlined,
              message: 'This shared link has expired.',
            ),
          ),
        );

      case PublicGalleryStatus.error:
        return Scaffold(
          appBar: const CustomAppBar(title: 'Shared Gallery', showBack: true),
          body: Center(
            child: EmptyStateCard(
              icon: Icons.wifi_off_rounded,
              message: controller.errorMessage ??
                  "Couldn't reach the server. Check your connection and try again.",
            ),
          ),
        );

      case PublicGalleryStatus.needsPassword:
      case PublicGalleryStatus.wrongPassword:
      case PublicGalleryStatus.downloadsDisabled:
        return _buildPasscodeGate(context, controller);

      case PublicGalleryStatus.loaded:
        return _buildGallery(context, controller.data!);
    }
  }

  // -------------------------------------------------------------
  // PRIVATE GALLERY ACCESS SCREEN (Passcode Gate)
  // -------------------------------------------------------------
  Widget _buildPasscodeGate(BuildContext context, PublicGalleryController controller) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Private Access',
            style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: GlassCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                borderRadius: AppRadius.lg,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lock_person_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Password Protected',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This gallery contains private content. Enter the passcode to continue.',
                        style: TextStyle(fontSize: 12, color: AppColors.subtitle, height: 1.4),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'Passcode',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.text),
                      ),
                      const SizedBox(height: 6),
                      CustomTextField(
                        label: 'Enter Passcode',
                        icon: Icons.key_rounded,
                        controller: _passwordController,
                        obscureText: _obscurePasscode,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Enter passcode';
                          return null;
                        },
                      ),
                      if (controller.status == PublicGalleryStatus.wrongPassword) ...[
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'Incorrect passcode. Please try again.',
                          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      GradientButton(
                        label: 'Unlock & View Gallery',
                        onPressed: _submitPasscode,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // PUBLIC OR UNLOCKED GALLERY SCREEN (Parallax Cover, Info, Grid)
  // -------------------------------------------------------------
  Widget _buildGallery(BuildContext context, PublicGalleryData data) {
    final albumMedia = List<MediaModel>.from(data.media)
      ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    final hasCover = albumMedia.isNotEmpty;
    final coverMedia = hasCover ? albumMedia.first : null;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                data.album.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
                ),
              ),
              centerTitle: true,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _buildCoverImage(coverMedia, data.album.gradientArgb),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black38, Colors.black87],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: data.requiresPassword
                              ? Colors.purple.withOpacity(0.12)
                              : Colors.blue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: data.requiresPassword
                                ? Colors.purple.withOpacity(0.3)
                                : Colors.blue.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(data.requiresPassword ? Icons.lock_open_rounded : Icons.public_rounded,
                                size: 12, color: data.requiresPassword ? Colors.purple : Colors.blue),
                            const SizedBox(width: 4),
                            Text(
                              data.requiresPassword ? 'Private Unlocked' : 'Public Gallery',
                              style: TextStyle(
                                  color: data.requiresPassword ? Colors.purple : Colors.blue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${albumMedia.length} Photos & Videos',
                          style: const TextStyle(color: AppColors.subtitle, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Welcome to your proofing gallery. Tap any image to review details, zoom, or playback video.',
                    style: TextStyle(color: AppColors.subtitle, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: AppColors.border),
                ],
              ),
            ),
          ),
          albumMedia.isEmpty
              ? const SliverFillRemaining(
                  child: Center(
                    child: EmptyStateCard(
                      icon: Icons.photo_library_outlined,
                      message: 'This shared gallery contains no photos.',
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.0,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final m = albumMedia[i];
                        return _buildGridItem(context, m, albumMedia, data.showWatermark, data.allowDownload);
                      },
                      childCount: albumMedia.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildCoverImage(MediaModel? media, List<int> fallbackGradient) {
    if (media == null) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2C3E50), Color(0xFF000000)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Icon(Icons.photo_library_rounded, color: Colors.white24, size: 48),
        ),
      );
    }
    final path = media.displayPath;
    final isNetwork = media.isDisplayPathNetwork;
    if (path.isNotEmpty) {
      if (isNetwork) {
        return Image.network(
          path,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(media.gradientArgb.first), Color(media.gradientArgb[1])],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        );
      }
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(fallbackGradient.first), Color(fallbackGradient.length > 1 ? fallbackGradient[1] : fallbackGradient.first)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  Widget _gridPlaceholder(MediaModel m) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(m.gradientArgb.first),
            Color(m.gradientArgb[1]),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          m.type == MediaType.photo ? Icons.image_rounded : Icons.play_arrow_rounded,
          color: Colors.white60,
        ),
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, MediaModel m, List<MediaModel> allMedia, bool showWatermark, bool allowDownload) {
    final thumbPath = m.displayThumbnailPath;
    final isNetwork = thumbPath.startsWith('http://') || thumbPath.startsWith('https://');
    final file = (!isNetwork && thumbPath.isNotEmpty) ? File(thumbPath) : null;
    final hasRealFile = isNetwork || (file != null && file.existsSync());

    Widget imageWidget;
    if (isNetwork) {
      imageWidget = Image.network(
        thumbPath,
        fit: BoxFit.cover,
        cacheWidth: 300,
        errorBuilder: (_, __, ___) => _gridPlaceholder(m),
      );
    } else if (hasRealFile) {
      imageWidget = Image.file(
        file!,
        fit: BoxFit.cover,
        cacheWidth: 300,
      );
    } else {
      imageWidget = _gridPlaceholder(m);
    }

    return GestureDetector(
      onTap: () {
        // mediaItems is passed explicitly (rather than relying on
        // mediaProvider) because this media belongs to a studio the
        // guest doesn't own/isn't signed in as — mediaProvider would be
        // empty or 403 here. readOnly hides owner-only actions (Move,
        // Copy, Rename, Delete, Edit) that would otherwise try to
        // mutate media the guest has no rights over.
        if (m.type == MediaType.photo) {
          Navigator.of(context).pushNamed(
            AppRoutes.imageViewer,
            arguments: ImageViewerArgs(
              mediaIds: allMedia.map((x) => x.id).toList(),
              initialIndex: allMedia.indexOf(m),
              showWatermark: showWatermark,
              allowDownload: allowDownload,
              shareLinkId: widget.token,
              mediaItems: allMedia,
              readOnly: true,
            ),
          );
        } else {
          Navigator.of(context).pushNamed(
            AppRoutes.videoPlayer,
            arguments: VideoPlayerArgs(
              mediaId: m.id,
              mediaIds: allMedia.map((x) => x.id).toList(),
              initialIndex: allMedia.indexOf(m),
              showWatermark: showWatermark,
              allowDownload: allowDownload,
              shareLinkId: widget.token,
              mediaItems: allMedia,
              readOnly: true,
            ),
          );
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageWidget,
            if (m.type == MediaType.video)
              Positioned(
                bottom: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            if (showWatermark)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: RotationTransition(
                      turns: const AlwaysStoppedAnimation(-25 / 360),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black12.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'picgallery',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.24),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
