import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user.dart';
import '../../providers/auth_providers.dart';
import '../../l10n/app_localizations.dart';

import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/screen_backdrop.dart';
import '../../widgets/navigation/custom_bottom_nav.dart';
import 'alerts_screen.dart';
import 'gallery_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import '../../widgets/navigation/client_drawer.dart';

class MainNavScreen extends ConsumerStatefulWidget {
  const MainNavScreen({super.key});

  @override
  ConsumerState<MainNavScreen> createState() => MainNavScreenState();
}

class MainNavScreenState extends ConsumerState<MainNavScreen> {
  int _navIndex = 0;
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  void goToTab(int index) => setState(() => _navIndex = index);

  void openDrawer() {
    scaffoldKey.currentState?.openDrawer();
  }

  late final _tabs = [
    const HomeScreen(),
    const GalleryScreen(),
    const Padding(
      padding: EdgeInsets.only(top: kToolbarHeight),
      child: AlertsScreen(),
    ),
    const Padding(
      padding: EdgeInsets.only(top: kToolbarHeight),
      child: ProfileScreen(),
    ),
  ];

  bool get _isHomeTab => _navIndex == 0;

  String _getTabTitle(BuildContext context, int index) {
    final l10n = AppLocalizations.of(context)!;
    switch (index) {
      case 0:
        return l10n.home;
      case 1:
        return l10n.gallery;
      case 2:
        return l10n.notifications;
      case 3:
        return l10n.profile;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authProvider).valueOrNull;
    if (authUser != null && authUser.role == AppUserRole.photographer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.adminHome);
        }
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      key: scaffoldKey,
      
      extendBodyBehindAppBar: true,
      drawer: ClientDrawer(
        currentIndex: _navIndex,
        onNavigateToTab: (i) => setState(() => _navIndex = i),
      ),
      appBar: (_navIndex == 1 || _isHomeTab)
          ? null
          : _buildTabAppBar(context, _getTabTitle(context, _navIndex)),
      body: ScreenBackdrop(
        child: SafeArea(
          top: !_isHomeTab,
          child: IndexedStack(index: _navIndex, children: _tabs),
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
      ),
    );
  }

  PreferredSizeWidget _buildTabAppBar(BuildContext context, String title) {
    return CustomAppBar(
      showBack: false,
      title: title,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => openDrawer(),
        ),
      ),
    );
  }
}
