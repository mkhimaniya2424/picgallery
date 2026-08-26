import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/screen_backdrop.dart';
import '../../services/permission_service.dart';

/// Read/write view of the three permission flags the onboarding
/// screens (`camera_permission_screen.dart`, etc.) originally set —
/// lets the user come back later and see/change what they granted,
/// instead of those flags only ever being set once during onboarding
/// and never visible again.
///
/// Same real `PUT /auth/permissions` endpoint as onboarding (only the
/// one flag that changed is sent). NOTE: toggling a switch here still
/// only writes our own record of what the user said yes/no to — it does
/// NOT call `PermissionService` to re-trigger the native OS dialog or
/// open device Settings. That means: (a) flipping a switch ON here
/// won't actually grant the OS permission if it was denied/permanently
/// denied, and (b) if the OS permission is separately revoked in device
/// Settings, this screen won't reflect that until the value is
/// re-synced (e.g. on next app launch) with `PermissionService`'s
/// `.status` checks. Wiring these switches to `PermissionService`
/// (`.request()` for turning on, `openAppSettingsPage()` when
/// permanently denied) is a reasonable next step but is out of scope
/// for what's implemented here.
class AppPermissionsScreen extends ConsumerStatefulWidget {
  const AppPermissionsScreen({super.key});

  @override
  ConsumerState<AppPermissionsScreen> createState() => _AppPermissionsScreenState();
}

class _AppPermissionsScreenState extends ConsumerState<AppPermissionsScreen> {
  /// Which permission (if any) has an update in flight — 'camera' |
  /// 'photos' | 'push' | null — so only the row being changed shows a
  /// spinner and the others stay interactive.
  String? _updating;

  Future<void> _toggle({
    required String key,
    required bool value,
    required Future<bool> Function()? requestPermission,
    required Future<AppUser> Function(bool) call,
  }) async {
    setState(() => _updating = key);
    try {
      bool finalValue = value;
      if (value && requestPermission != null) {
        finalValue = await requestPermission();
        if (!finalValue && mounted) {
          AppToast.show(context, 'Permission denied in OS settings. Please enable it there first.', isError: true);
        }
      }
      final updated = await call(finalValue);
      ref.read(authProvider.notifier).setUser(updated);
    } on ApiException catch (e) {
      if (mounted) AppToast.show(context, e.message, isError: true);
    } catch (_) {
      if (mounted) AppToast.show(context, 'Could not update permission. Try again.', isError: true);
    } finally {
      if (mounted) setState(() => _updating = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;

    return Scaffold(
      appBar: const CustomAppBar(title: 'App Permissions'),
      body: ScreenBackdrop(
        child: SafeArea(
          top: false,
          child: user == null
              ? const Center(child: LoadingWidget())
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    Text(
                      'What picgallery can access',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'These reflect what you allowed during setup — flip any of them here instead.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _PermissionCard(
                      icon: Icons.camera_alt_rounded,
                      title: 'Camera',
                      description: 'Capture and upload photos directly from the app.',
                      granted: user.cameraPermissionGranted,
                      isUpdating: _updating == 'camera',
                      onChanged: (v) => _toggle(
                        key: 'camera',
                        value: v,
                        requestPermission: () => PermissionService.instance.checkAndRequestCameraPermission(),
                        call: (finalV) => ref.read(authRepositoryProvider).updatePermissions(cameraPermissionGranted: finalV),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _PermissionCard(
                      icon: Icons.photo_library_rounded,
                      title: 'Photo Library',
                      description: 'Import photos from your device into albums.',
                      granted: user.photoLibraryPermissionGranted,
                      isUpdating: _updating == 'photos',
                      onChanged: (v) => _toggle(
                        key: 'photos',
                        value: v,
                        requestPermission: () => PermissionService.instance.checkAndRequestStoragePermission(),
                        call: (finalV) =>
                            ref.read(authRepositoryProvider).updatePermissions(photoLibraryPermissionGranted: finalV),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _PermissionCard(
                      icon: Icons.notifications_active_rounded,
                      title: 'Push Notifications',
                      description: 'Get notified about new galleries, downloads and activity.',
                      granted: user.pushNotificationsEnabled,
                      isUpdating: _updating == 'push',
                      onChanged: (v) => _toggle(
                        key: 'push',
                        value: v,
                        requestPermission: () => PermissionService.instance.checkAndRequestNotificationPermission(),
                        call: (finalV) => ref.read(authRepositoryProvider).updatePermissions(pushNotificationsEnabled: finalV),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool granted;
  final bool isUpdating;
  final ValueChanged<bool> onChanged;

  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.granted,
    required this.isUpdating,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardFill = isDark ? AppColors.darkSurface : AppColors.surfaceElevated;
    final cardBorder = isDark ? AppColors.darkBorder : AppColors.border;
    final textColor = isDark ? AppColors.textOnDark : AppColors.text;
    final subtitleColor = isDark ? AppColors.subtitleOnDark : AppColors.subtitle;
    // A flat, low-alpha tint reads as a crisp pastel badge on the light
    // card, but the same 12% alpha over a near-black dark card comes out
    // as a faint, undefined smudge with no visible edge. Bump the fill
    // and add a thin ring in the same hue so the badge stays a clearly
    // readable circle on dark surfaces too.
    final badgeFillAlpha = isDark ? 0.20 : 0.12;
    final badgeBorderAlpha = isDark ? 0.45 : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (granted ? AppColors.success : subtitleColor).withValues(alpha: badgeFillAlpha),
              shape: BoxShape.circle,
              border: badgeBorderAlpha > 0
                  ? Border.all(
                      color: (granted ? AppColors.success : subtitleColor).withValues(alpha: badgeBorderAlpha),
                      width: 1,
                    )
                  : null,
            ),
            child: Icon(icon, size: 20, color: granted ? AppColors.success : subtitleColor),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: textColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (granted ? AppColors.success : subtitleColor).withValues(alpha: badgeFillAlpha),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: badgeBorderAlpha > 0
                            ? Border.all(
                                color: (granted ? AppColors.success : subtitleColor)
                                    .withValues(alpha: badgeBorderAlpha),
                                width: 1,
                              )
                            : null,
                      ),
                      child: Text(
                        granted ? 'Granted' : 'Not Granted',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: granted ? AppColors.success : subtitleColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(description, style: TextStyle(fontSize: 12, color: subtitleColor, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          isUpdating
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: Padding(
                    padding: EdgeInsets.all(2),
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                )
              : Switch.adaptive(
                  value: granted,
                  activeColor: AppColors.primary,
                  onChanged: onChanged,
                ),
        ],
      ),
    );
  }
}