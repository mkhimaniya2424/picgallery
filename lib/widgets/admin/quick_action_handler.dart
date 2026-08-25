import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/subscription_guard.dart';
import '../../models/admin_dashboard_data.dart';
import '../../providers/admin_dashboard_providers.dart';
import '../../providers/auth_providers.dart';

/// Shared execution logic for a [QuickActionData] tap.
///
/// Quick Actions themselves stay a static, locally-defined
/// id → behavior mapping (Task 20.11) — there's no backend concept of
/// a "quick action" at all (no endpoint lists them, no per-studio
/// customization exists), they're purely a fixed set of shortcuts into
/// screens/mutations the app already has, same as the tile grid in a
/// phone's control center. Making that list backend-driven would add a
/// round-trip for something that never changes and has no reason to
/// vary per studio.
///
/// What *did* need fixing here: several cases used to fabricate a
/// result locally (a made-up album name, a made-up notification) and
/// call an [AdminDashboardRepository] method that only
/// [InMemoryAdminDashboardRepository] ever actually implemented.
/// Against the real [ApiAdminDashboardRepository] those same calls
/// always throw [UnimplementedError] — see that class's doc comments
/// for exactly which endpoint (if any) is supposed to back each one.
/// Every case below either calls a mutation the API repository
/// genuinely implements, routes to the real screen that owns that
/// action, or — where no real backend feature exists yet at all
/// (QR check-in) — says so honestly instead of faking success.
///
/// Extracted out of [StudioDashboardScreen] so the standalone
/// [QuickActionsScreen] can trigger the exact same behavior through
/// [adminDashboardProvider] — there is only ever one implementation of
/// "what a quick action does", reused by both the Dashboard's inline
/// grid and the full Quick Actions screen.
class QuickActionHandler {
  QuickActionHandler._();

  static Future<void> execute({
    required BuildContext context,
    required WidgetRef ref,
    required QuickActionData action,
    required void Function(String message, {Color? color}) toast,
    VoidCallback? onBeforeReport,
    /// Switches the enclosing [AdminMainNavScreen] to another bottom-nav
    /// tab (0=Dashboard, 1=Gallery, 2=Clients, 3=Profile) —
    /// same callback [StudioDashboardScreen] already threads down to

    /// e.g. its "See All" buttons. Only available when [execute] is
    /// called from inside that IndexedStack (the Dashboard's inline
    /// grid); the standalone [QuickActionsScreen] is reached via a
    /// pushed route and has no such callback, so this is `null` there
    /// and the affected cases fall back to a toast telling the studio
    /// which tab to open instead.
    ValueChanged<int>? onNavigateToTab,
  }) async {
    switch (action.id) {
      case 'upload_photos':
      case 'upload_videos':
        // Real uploads go through MediaUploadService / POST
        // /media/upload from UploadQueueScreen, which needs actual
        // picked file bytes — AdminDashboardRepository.addUpload has
        // none of that to work with and always throws against the
        // real backend, so route to the real screen instead of faking
        // a finished upload.
        Navigator.of(context).pushNamed(AppRoutes.uploadQueue);
        break;
      case 'create_album':
        // Same reasoning as uploads above — CreateAlbumScreen owns the
        // real album-creation flow (POST /albums); addUpload can't
        // back this against the real API.
        requireActiveSubscription(context, ref, () {
          Navigator.of(context).pushNamed(AppRoutes.adminAlbumCreate);
        });
        break;
      case 'add_client':
        _goToClientsTab(context, toast, onNavigateToTab);
        break;
      case 'share_gallery':
        _goToGalleryTab(context, toast, onNavigateToTab);
        break;
      case 'scan_qr':
        _showQrDialog(context, ref);
        break;

      case 'reports':
        Navigator.of(context).pushNamed(AppRoutes.adminAnalytics);
        break;
      default:
        toast(action.label.replaceAll('\n', ' '));
    }
  }

  /// Clients only ever come from an accepted studio↔client connection
  /// server-side — there is no "create a client from a typed name"
  /// endpoint, so [AdminDashboardRepository.addClient] always throws
  /// against [ApiAdminDashboardRepository]. The real invite flow lives
  /// on the Clients tab ([AdminClientsScreen]), so route there instead
  /// of collecting a name here that has nowhere real to go.
  ///
  /// When called from the Dashboard's inline grid, [onNavigateToTab]
  /// switches the bottom-nav tab directly. When called from the
  /// standalone [QuickActionsScreen] (reached via `pushNamed`, so there's
  /// no bottom-nav tab to switch), this instead pops back with the
  /// target tab index as the pop result — `admin_dashboard_screen.dart`
  /// awaits that result and forwards it to the real `onNavigateToTab`,
  /// so the tile behaves the same regardless of which screen it was
  /// tapped from. A toast only remains as a last-resort fallback if
  /// there's somehow nothing to pop back into.
  static void _goToClientsTab(
    BuildContext context,
    void Function(String message, {Color? color}) toast,
    ValueChanged<int>? onNavigateToTab,
  ) {
    if (onNavigateToTab != null) {
      onNavigateToTab(2);
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(2);
    } else {
      toast('Open the Clients tab to add a client');
    }
  }

  /// Sharing needs one specific album (`ShareSettingsScreen.albumId`)
  /// — there is no "share whichever gallery was uploaded most
  /// recently" endpoint, so [AdminDashboardRepository.shareGallery]
  /// always throws against [ApiAdminDashboardRepository]. Route to the
  /// Gallery tab so the studio can pick an album and use its real
  /// Share Settings screen instead of guessing at one here. Same
  /// pop-with-tab-index fallback as [_goToClientsTab] above.
  static void _goToGalleryTab(
    BuildContext context,
    void Function(String message, {Color? color}) toast,
    ValueChanged<int>? onNavigateToTab,
  ) {
    if (onNavigateToTab != null) {
      onNavigateToTab(1);
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(1);
    } else {
      toast('Open the Gallery tab to share an album');
    }
  }



  /// Encodes the studio's real `AppUser.id` — not the display name,
  /// which isn't a valid lookup key anywhere in the app — as a
  /// `picgallery://studio/{studioId}` deep link. `DeepLinkService`
  /// resolves that into the same `StudioProfileScreen` used everywhere
  /// else a studio is viewed. There is still no backend "check-in"
  /// concept, so this is an honest "view studio profile" shortcut, not
  /// a check-in — hence "Studio Code", not "Check-in", in the label and
  /// caption.
  static void _showQrDialog(BuildContext context, WidgetRef ref) {
    final dashboard = ref.read(adminDashboardProvider).valueOrNull;
    final studioName = dashboard?.studioName ?? 'PicGallery Studio';
    final studioId = ref.read(authStateProvider).user?.id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (studioId == null || studioId.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
          title: Text(
            'Studio QR Code',
            style: TextStyle(color: isDark ? AppColors.textOnDark : AppColors.text, fontWeight: FontWeight.bold),
          ),
          content: Text(
            "Couldn't generate a code — please sign in again and retry.",
            style: TextStyle(color: isDark ? AppColors.subtitleOnDark : AppColors.subtitle, fontSize: 13.5),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
          title: Text(
            'Studio QR Code',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? AppColors.textOnDark : AppColors.text,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Scan to view $studioName\'s profile',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? AppColors.subtitleOnDark : AppColors.subtitle,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: QrImageView(
                  data: 'picgallery://studio/$studioId',
                  version: QrVersions.auto,
                  size: 200.0,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}