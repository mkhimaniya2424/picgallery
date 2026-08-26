import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/auth_providers.dart';
import '../../services/permission_service.dart';
import '../../widgets/common/permission_request_sheet.dart';

/// Last of three onboarding permission prompts (camera → photo library →
/// push notifications). Both "Allow Access" and "Not Now" finish
/// onboarding the same way, landing photographers on Admin Home and
/// clients on Home, and clearing the whole auth stack so there's no way
/// back into onboarding.
///
/// "Allow Access" first triggers the real native notification
/// permission dialog via `PermissionService`, then sends
/// `PUT /auth/permissions` with `push_notifications_enabled: <result>`.
/// "Not Now" skips both the native prompt and the call entirely — both
/// buttons always finish onboarding regardless of the outcome.
class PushNotificationPermissionScreen extends ConsumerWidget {
  final UserRole? role;
  const PushNotificationPermissionScreen({super.key, this.role});

  void _finish(BuildContext context) {
    final destination = role == UserRole.photographer ? AppRoutes.adminHome : AppRoutes.home;
    Navigator.of(context).pushNamedAndRemoveUntil(destination, (route) => false);
  }

  Future<void> _allow(BuildContext context, WidgetRef ref) async {
    final granted = await PermissionService.instance.checkAndRequestNotificationPermission();
    try {
      final updated = await ref
          .read(authRepositoryProvider)
          .updatePermissions(pushNotificationsEnabled: granted);
      // Without this, the PUT succeeds server-side but the app's cached
      // AppUser (authProvider) still holds the pre-onboarding value —
      // so Notification Settings shows the toggle OFF right after
      // onboarding even when the user just granted permission, until
      // something else (pull-to-refresh, editing the profile) happens
      // to call refreshMe(). Same fix applies to camera/photo-library
      // permission screens, which have the identical discard pattern.
      ref.read(authProvider.notifier).setUser(updated);
    } on ApiException {
      // Best-effort — finish regardless, same as "Not Now".
    }
    if (context.mounted) _finish(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PermissionRequestSheet(
      icon: Icons.notifications_active_rounded,
      title: 'Stay in the Loop',
      description: 'Get notified about bookings, messages, and delivery updates',
      onAllow: () => _allow(context, ref),
      onSkip: () => _finish(context),
    );
  }
}