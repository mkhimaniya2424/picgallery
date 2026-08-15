import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/screen_backdrop.dart';
import '../../widgets/navigation/custom_bottom_nav.dart';
import 'alerts_screen.dart';
import 'gallery_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import '../../widgets/navigation/client_drawer.dart';

/// The single post-auth Scaffold, shared by every bottom-nav destination
/// (Home, Gallery, Alerts, Profile) so the bottom nav bar is identical,
/// persistent chrome instead of each tab building its own — only the
/// body swaps, via an [IndexedStack] that keeps every tab's scroll
/// position and state alive when switching back and forth.
///
/// Gallery and Home render their own chrome (Home has a full-bleed
/// gradient hero header baked into its body); Alerts and Profile share
/// the app's normal light [CustomAppBar].
class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => MainNavScreenState();
}

class MainNavScreenState extends State<MainNavScreen> {
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
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: AppColors.background,
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
