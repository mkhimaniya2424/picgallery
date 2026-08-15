import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/common/permission_request_sheet.dart';

/// Last of three onboarding permission prompts (camera → photo library →
/// push notifications). Both "Allow Access" and "Not Now" finish
/// onboarding the same way, landing photographers on Admin Home and
/// clients on Home, and clearing the whole auth stack so there's no way
/// back into onboarding.
///
/// "Allow Access" sends `PUT /auth/permissions` with just
/// `push_notifications_enabled: true`. "Not Now" skips the call
/// entirely — both buttons always finish onboarding regardless of the
/// API result.
class PushNotificationPermissionScreen extends ConsumerWidget {
  final UserRole? role;
  const PushNotificationPermissionScreen({super.key, this.role});

  void _finish(BuildContext context) {
    final destination = role == UserRole.photographer ? AppRoutes.adminHome : AppRoutes.home;
    Navigator.of(context).pushNamedAndRemoveUntil(destination, (route) => false);
  }

  Future<void> _allow(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authRepositoryProvider).updatePermissions(pushNotificationsEnabled: true);
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
