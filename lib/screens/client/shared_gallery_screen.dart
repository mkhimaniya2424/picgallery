import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/media_format_utils.dart';
import '../../models/album_model.dart';
import '../../models/media_model.dart';
import '../../providers/album_provider.dart';
import '../../providers/media_provider.dart';
import '../../providers/share_link_provider.dart';
import '../media/image_viewer_screen.dart';
import '../media/video_player_screen.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/empty_state_card.dart';
import '../../widgets/cards/glass_card.dart';
import '../../widgets/buttons/gradient_button.dart';
import '../../widgets/inputs/custom_text_field.dart';

class SharedGalleryScreen extends ConsumerStatefulWidget {
  final String linkId;

  const SharedGalleryScreen({super.key, required this.linkId});

  @override
  ConsumerState<SharedGalleryScreen> createState() => _SharedGalleryScreenState();
}

class _SharedGalleryScreenState extends ConsumerState<SharedGalleryScreen> {
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _unlocked = false;
  String? _passError;
  bool _viewIncremented = false;

  bool _obscurePasscode = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _incrementViewOnce() {
    if (_viewIncremented) return;
    _viewIncremented = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shareLinkProvider.notifier).incrementViews(widget.linkId);
    });
  }

  void _verifyPassword(String correctPassword) {
    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _passError = 'Please enter your name.';
      });
      return;
    }
    if (_passwordController.text == correctPassword) {
      setState(() {
        _unlocked = true;
        _passError = null;
      });
    } else {
      setState(() {
        _passError = 'Incorrect passcode. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final shareState = ref.watch(shareLinkProvider);
    final link = shareState.getLinkById(widget.linkId);

    if (link == null) {
      return const Scaffold(
        appBar: CustomAppBar(title: 'Shared Gallery', showBack: true),
        body: Center(
          child: EmptyStateCard(
            icon: Icons.search_off_rounded,
            message: 'This shared link does not exist.',
          ),
        ),
      );
    }

    if (link.revoked) {
      return const Scaffold(
        appBar: CustomAppBar(title: 'Shared Gallery', showBack: true),
        body: Center(
          child: EmptyStateCard(
            icon: Icons.link_off_rounded,
            message: 'This shared link has been revoked by the photographer.',
          ),
        ),
      );
    }

    if (link.isExpired) {
      return const Scaffold(
        appBar: CustomAppBar(title: 'Shared Gallery', showBack: true),
        body: Center(
          child: EmptyStateCard(
            icon: Icons.lock_clock_outlined,
            message: 'This shared link has expired.',
          ),
        ),
      );
    }

    // Accessible gallery properties
    final albums = ref.watch(albumProvider).allAlbums;
    final album = albums.cast<AlbumModel?>().firstWhere(
          (a) => a?.id == link.albumId,
          orElse: () => null,
        );

    if (album == null) {
      return const Scaffold(
        appBar: CustomAppBar(title: 'Shared Gallery', showBack: true),
        body: Center(
          child: EmptyStateCard(
            icon: Icons.photo_album_outlined,
            message: 'The shared album no longer exists.',
          ),
        ),
      );
    }

    final mediaState = ref.watch(mediaProvider);
    final albumMedia = mediaState.allMedia
        .where((m) => m.albumId == album.id && !m.isDeleted)
        .toList()
      ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));

    final hasCover = albumMedia.isNotEmpty;
    final coverMedia = hasCover ? albumMedia.first : null;

    // -------------------------------------------------------------
    // PRIVATE GALLERY ACCESS SCREEN (Passcode Validation & Config View)
    // -------------------------------------------------------------
    if (!link.isPublic && !_unlocked) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.text, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Private Access', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w800)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    // Mini Cover Image Banner
                    Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildCoverImage(coverMedia),
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.black26, Colors.black87],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 12,
                            left: 16,
                            right: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  album.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Private Collection • ${albumMedia.length} item(s)',
                                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    GlassCard(
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
                              'This gallery contains private content. Choose your profile and input the correct passcode.',
                              style: TextStyle(fontSize: 12, color: AppColors.subtitle, height: 1.4),
                            ),
                            const SizedBox(height: AppSpacing.md),

                            // Viewer Name Field
                            const Text(
                              'Your Name',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.text),
                            ),
                            const SizedBox(height: 6),
                            CustomTextField(
                              label: 'Enter your name',
                              icon: Icons.person_rounded,
                              controller: _nameController,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Enter your name';
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.md),

                            // Passcode Field
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
                            if (_passError != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                _passError!,
                                style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.md),

                            // Settings Summary Info Card
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.background.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                children: [
                                  _infoTile(
                                    icon: Icons.date_range_rounded,
                                    label: 'Expiry:',
                                    value: link.expiryDate != null
                                        ? MediaFormatUtils.formatDate(link.expiryDate!)
                                        : 'Never Expires',
                                  ),
                                  const Divider(height: 12),
                                  _infoTile(
                                    icon: Icons.download_for_offline_rounded,
                                    label: 'Downloads:',
                                    value: link.allowDownload ? 'Allowed' : 'Disabled',
                                    valColor: link.allowDownload ? Colors.green : Colors.red,
                                  ),
                                  const Divider(height: 12),
                                  _infoTile(
                                    icon: Icons.copyright_rounded,
                                    label: 'Watermark:',
                                    value: link.showWatermark ? 'Active overlay' : 'None',
                                    valColor: link.showWatermark ? Colors.orange : Colors.grey,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: AppSpacing.lg),
                            GradientButton(
                              label: 'Unlock & View Gallery',
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  _verifyPassword(link.password ?? '');
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Increment analytics view count since the link is unlocked and visible
    _incrementViewOnce();

    // -------------------------------------------------------------
    // PUBLIC OR UNLOCKED GALLERY SCREEN (Parallax Cover, Info, Grid)
    // -------------------------------------------------------------
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Cover Image Parallax Header
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.background,
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
                album.name,
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
                  _buildCoverImage(coverMedia),
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

          // 2. Gallery Information Panel
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
                          color: link.isPublic ? Colors.blue.withOpacity(0.12) : Colors.purple.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: link.isPublic ? Colors.blue.withOpacity(0.3) : Colors.purple.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(link.isPublic ? Icons.public_rounded : Icons.lock_open_rounded,
                                size: 12, color: link.isPublic ? Colors.blue : Colors.purple),
                            const SizedBox(width: 4),
                            Text(
                              link.isPublic ? 'Public Gallery' : 'Private Unlocked',
                              style: TextStyle(
                                  color: link.isPublic ? Colors.blue : Colors.purple,
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
                    'Welcome to your proofing gallery. Tap any image to review details, zoom, or playback video. Use shared controls inside to download or share.',
                    style: TextStyle(color: AppColors.subtitle, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: AppColors.border),
                ],
              ),
            ),
          ),

          // 3. Media Grid
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
                        return _buildGridItem(context, m, albumMedia, link.showWatermark, link.allowDownload);
                      },
                      childCount: albumMedia.length,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildCoverImage(MediaModel? media) {
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
          colors: [Color(media.gradientArgb.first), Color(media.gradientArgb[1])],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  Widget _infoTile({required IconData icon, required String label, required String value, Color? valColor}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.subtitle),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: AppColors.subtitle, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: valColor ?? AppColors.text, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ],
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
        if (m.type == MediaType.photo) {
          Navigator.of(context).pushNamed(
            AppRoutes.imageViewer,
            arguments: ImageViewerArgs(
              mediaIds: allMedia.map((x) => x.id).toList(),
              initialIndex: allMedia.indexOf(m),
              showWatermark: showWatermark,
              allowDownload: allowDownload,
              shareLinkId: widget.linkId,
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
              shareLinkId: widget.linkId,
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
