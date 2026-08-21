import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/studio_model.dart';
import '../../providers/studio_provider.dart';
import '../../widgets/cards/glass_card.dart';
import '../../widgets/common/inline_error_banner.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/safe_network_image.dart';

class StudioProfileScreen extends ConsumerStatefulWidget {
  final String studioId;

  const StudioProfileScreen({super.key, required this.studioId});

  @override
  ConsumerState<StudioProfileScreen> createState() => _StudioProfileScreenState();
}

class _StudioProfileScreenState extends ConsumerState<StudioProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isOpeningViewer = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Always refresh the studio directory when this screen opens so a
      // newly updated logo/cover from Edit Studio Profile is not hidden by
      // stale cached data already sitting in the provider.
      ref.read(studioProvider.notifier).loadDirectory();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(studioProvider);

    if (provider.isLoadingDirectory && provider.studios.isEmpty) {
      return Scaffold(
        
        appBar: AppBar(backgroundColor: AppColors.primary, elevation: 0),
        body: const Center(child: LoadingWidget(message: 'Loading studio…')),
      );
    }

    if (provider.directoryError != null && provider.studios.isEmpty) {
      return Scaffold(
        
        appBar: AppBar(backgroundColor: AppColors.primary, elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: InlineErrorBanner(
              message: provider.directoryError!,
              action: TextButton(
                onPressed: () => ref.read(studioProvider.notifier).loadDirectory(),
                child: const Text('Retry'),
              ),
            ),
          ),
        ),
      );
    }

    final studioIndex = provider.studios.indexWhere((s) => s.id == widget.studioId);
    if (studioIndex == -1) {
      return Scaffold(
        
        appBar: AppBar(backgroundColor: AppColors.primary, elevation: 0),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Text(
              "This studio couldn't be found.",
              style: TextStyle(color: AppColors.subtitle, fontSize: 14),
            ),
          ),
        ),
      );
    }
    final studio = provider.studios[studioIndex];

    return Scaffold(
      
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 240,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.primary,
              iconTheme: const IconThemeData(color: Colors.white),
              elevation: 0,
              actions: [
                IconButton(
                  icon: Icon(
                    studio.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: studio.isFavorite ? AppColors.error : Colors.white,
                  ),
                  onPressed: () => ref.read(studioProvider.notifier).toggleFavorite(studio.id),
                ),
                IconButton(
                  icon: const Icon(Icons.share_rounded),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied ${studio.name} profile link!'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    SafeNetworkImage(
                      studio.coverUrl,
                      placeholderIcon: Icons.landscape_rounded,
                      fit: BoxFit.cover,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black45,
                            Colors.transparent,
                            Colors.black87,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Studio Info Header Area
              Transform.translate(
                offset: const Offset(0, -30),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Studio Logo
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: SafeNetworkImage(
                              studio.logoUrl,
                              placeholderIcon: Icons.business_rounded,
                              fit: BoxFit.cover,
                              borderRadius: BorderRadius.circular(1000),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Rating & Quick stats
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.star_rounded, color: AppColors.gold, size: 20),
                                  const SizedBox(width: 4),
                                  Text(
                                    studio.rating.toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '(${studio.reviewCount} Reviews)',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Name, Location and Web
                      Text(
                        studio.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 16),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              studio.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.subtitle, fontSize: 13.5),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.link_rounded, color: AppColors.primary, size: 16),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              studio.website,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Tags
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: studio.categories.map((cat) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              cat,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Connect Button
                      _buildConnectButton(studio),
                      const SizedBox(height: 20),

                      // Tab Bar
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicatorColor: AppColors.primary,
                          indicatorWeight: 3,
                          labelColor: AppColors.primary,
                          unselectedLabelColor: AppColors.subtitle,
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                          tabs: const [
                            Tab(text: 'About'),
                            Tab(text: 'Portfolio Gallery'),
                          ],
                        ),
                      ),

                      // Tab Contents
                      const SizedBox(height: 16),
                      AnimatedBuilder(
                        animation: _tabController,
                        builder: (context, child) {
                          if (_tabController.index == 0) {
                            return _buildAboutTab(studio);
                          } else {
                            return _buildPortfolioTab(studio);
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
    );
  }

  Future<void> _handleConnectTap(StudioModel studio) async {
    final notifier = ref.read(studioProvider.notifier);

    switch (studio.connectionStatus) {
      case StudioConnectionStatus.notConnected:
        final success = await notifier.requestConnection(studio.id);
        if (!mounted) return;
        _showConnectSnack(
          success ? 'Connection request sent to ${studio.name}!' : 'Could not send the request. Try again.',
          isError: !success,
        );
        break;

      case StudioConnectionStatus.pending:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Withdraw request?'),
            content: Text('Your pending request to ${studio.name} will be withdrawn.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Withdraw')),
            ],
          ),
        );
        if (confirmed != true) return;
        final success = await notifier.withdrawConnectionRequest(studio.id);
        if (!mounted) return;
        _showConnectSnack(
          success ? 'Request to ${studio.name} withdrawn.' : 'Could not withdraw the request. Try again.',
          isError: !success,
        );
        break;

      case StudioConnectionStatus.connected:
        _showConnectSnack('You\'re already connected with ${studio.name}.');
        break;
    }
  }

  void _showConnectSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildConnectButton(StudioModel studio) {
    final status = studio.connectionStatus;
    final isPendingCall =
        ref.watch(studioProvider.select((p) => p.pendingConnectionIds.contains(studio.id)));
    Color buttonColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status) {
      case StudioConnectionStatus.notConnected:
        buttonColor = AppColors.primary;
        textColor = Colors.white;
        label = 'Connect with Studio';
        icon = Icons.add_circle_outline_rounded;
        break;
      case StudioConnectionStatus.pending:
        buttonColor = AppColors.primary.withValues(alpha: 0.12);
        textColor = AppColors.primary;
        label = 'Connection Request Pending';
        icon = Icons.hourglass_top_rounded;
        break;
      case StudioConnectionStatus.connected:
        buttonColor = AppColors.success;
        textColor = Colors.white;
        label = 'Connected';
        icon = Icons.check_circle_rounded;
        break;
    }

    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        boxShadow: status == StudioConnectionStatus.notConnected
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.24),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
      ),
      child: ElevatedButton.icon(
        onPressed: isPendingCall ? null : () => _handleConnectTap(studio),
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: status == StudioConnectionStatus.pending
                ? const BorderSide(color: AppColors.primary, width: 1.5)
                : BorderSide.none,
          ),
        ),
        icon: isPendingCall
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: textColor),
              )
            : Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildAboutTab(StudioModel studio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Biography Card
        GlassCard(
          borderRadius: 16,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'About the Studio',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                studio.about,
                style: const TextStyle(
                  color: AppColors.subtitle,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Contact details Card
        GlassCard(
          borderRadius: 16,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Contact Information',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              _buildContactRow(Icons.email_outlined, 'Email Address', studio.email),
              const Divider(color: AppColors.border, height: 20),
              _buildContactRow(Icons.public_outlined, 'Official Website', studio.website),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Business details
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Operational Hours',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Monday – Saturday: 10:00 AM – 7:30 PM\nSunday: By appointment only',
                style: TextStyle(
                  color: AppColors.subtitle,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildContactRow(IconData icon, String title, String val) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.subtitle,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                val,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPortfolioTab(StudioModel studio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Showcase Portfolio',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.8,
          ),
          itemCount: studio.galleryUrls.length,
          itemBuilder: (context, index) {
            final url = studio.galleryUrls[index];
            return GestureDetector(
              onTap: () {
                _openFullscreenViewer(context, studio.galleryUrls, index);
              },
              child: Hero(
                tag: 'portfolio-${studio.id}-$index',
                child: SafeNetworkImage(
                  url,
                  placeholderIcon: Icons.image_rounded,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(14),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: AppColors.border.withValues(alpha: 0.5),
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  void _openFullscreenViewer(BuildContext context, List<String> urls, int initialIndex) {
    // Guard against rapid double-taps pushing this route twice, which would
    // mount two Hero widgets with the same tag at once and crash Flutter's
    // Hero flight matching ("multiple heroes share the same tag" / the
    // Hero._allHeroesFor exception).
    if (_isOpeningViewer) return;
    _isOpeningViewer = true;

    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => FullscreenImageSwipeViewer(
          urls: urls,
          initialIndex: initialIndex,
          studioId: widget.studioId,
        ),
      ),
    ).then((_) {
      if (mounted) _isOpeningViewer = false;
    });
  }
}

class FullscreenImageSwipeViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  final String studioId;

  const FullscreenImageSwipeViewer({
    super.key,
    required this.urls,
    required this.initialIndex,
    required this.studioId,
  });

  @override
  State<FullscreenImageSwipeViewer> createState() => _FullscreenImageSwipeViewerState();
}

class _FullscreenImageSwipeViewerState extends State<FullscreenImageSwipeViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Swipeable Pages with Zoomable interactive viewers
          PageView.builder(
            controller: _pageController,
            itemCount: widget.urls.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Hero(
                tag: 'portfolio-${widget.studioId}-$index',
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: SafeNetworkImage(
                    widget.urls[index],
                    placeholderIcon: Icons.image_rounded,
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),

          // Safe Area HUD Overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button / Exit
                CircleAvatar(
                  backgroundColor: Colors.black45,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                // Indicator Text
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.urls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 40), // Placeholder to center indicator
              ],
            ),
          ),
        ],
      ),
    );
  }
}