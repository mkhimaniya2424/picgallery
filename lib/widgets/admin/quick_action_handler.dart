import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/subscription_guard.dart';
import '../../models/admin_dashboard_data.dart';
import '../../providers/admin_dashboard_providers.dart';

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
        _goToClientsTab(toast, onNavigateToTab);
        break;
      case 'share_gallery':
        _goToGalleryTab(toast, onNavigateToTab);
        break;
      case 'scan_qr':
        // No QR check-in backend exists yet — no endpoint, no model,
        // nothing for this to call. The old behavior faked a
        // notification to simulate one; better to say plainly that
        // it isn't available than to pretend it worked.
        toast('QR check-in isn\'t available yet');
        break;

      case 'reports':
        onBeforeReport?.call();
        await _generateAndShowReport(context, ref);
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
  static void _goToClientsTab(
    void Function(String message, {Color? color}) toast,
    ValueChanged<int>? onNavigateToTab,
  ) {
    if (onNavigateToTab != null) {
      onNavigateToTab(2);
    } else {
      toast('Open the Clients tab to add a client');
    }
  }

  /// Sharing needs one specific album (`ShareSettingsScreen.albumId`)
  /// — there is no "share whichever gallery was uploaded most
  /// recently" endpoint, so [AdminDashboardRepository.shareGallery]
  /// always throws against [ApiAdminDashboardRepository]. Route to the
  /// Gallery tab so the studio can pick an album and use its real
  /// Share Settings screen instead of guessing at one here.
  static void _goToGalleryTab(
    void Function(String message, {Color? color}) toast,
    ValueChanged<int>? onNavigateToTab,
  ) {
    if (onNavigateToTab != null) {
      onNavigateToTab(1);
    } else {
      toast('Open the Gallery tab to share an album');
    }
  }

  static Future<void> _generateAndShowReport(
      BuildContext context, WidgetRef ref) async {
    final summary =
        await ref.read(adminDashboardProvider.notifier).generateReport();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Latest Report'),
        content: Text(summary,
            style: const TextStyle(
                fontSize: 13.5, color: AppColors.subtitle, height: 1.5)),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done')),
        ],
      ),
    );
  }
}