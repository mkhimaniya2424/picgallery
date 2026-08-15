import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/common/permission_request_sheet.dart';

/// Second of three onboarding permission prompts (camera → photo library →
/// push notifications), shown after Complete Profile and before Home /
/// Admin Home.
///
/// "Allow Access" sends `PUT /auth/permissions` with just
/// `photo_library_permission_granted: true`. "Not Now" skips the call
/// entirely — both buttons always advance the flow regardless of the
/// API result.
class PhotoLibraryPermissionScreen extends ConsumerWidget {
  final UserRole? role;
  const PhotoLibraryPermissionScreen({super.key, this.role});

  void _advance(BuildContext context) {
    Navigator.of(context).pushReplacementNamed(AppRoutes.pushNotificationPermission, arguments: role);
  }

  Future<void> _allow(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authRepositoryProvider).updatePermissions(photoLibraryPermissionGranted: true);
    } on ApiException {
      // Best-effort — advance regardless, same as "Not Now".
    }
    if (context.mounted) _advance(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PermissionRequestSheet(
      icon: Icons.photo_library_rounded,
      title: 'Photo Library Access',
      description: 'Allow photo library access to import and share albums',
      onAllow: () => _allow(context, ref),
      onSkip: () => _advance(context),
    );
  }
}
