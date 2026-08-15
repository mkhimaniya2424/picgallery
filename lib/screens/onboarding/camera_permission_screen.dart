import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/common/permission_request_sheet.dart';

/// First of three onboarding permission prompts (camera → photo library →
/// push notifications), shown after Complete Profile and before Home /
/// Admin Home.
///
/// "Allow Access" sends `PUT /auth/permissions` with just
/// `camera_permission_granted: true` (per the backend's own doc-comment:
/// each screen only sends the one flag it owns). "Not Now" skips the
/// call entirely — per the brief, both buttons always advance the flow
/// regardless of the API result, so a failed/slow request never blocks
/// onboarding.
class CameraPermissionScreen extends ConsumerWidget {
  final UserRole? role;
  const CameraPermissionScreen({super.key, this.role});

  void _advance(BuildContext context) {
    Navigator.of(context).pushReplacementNamed(AppRoutes.photoLibraryPermission, arguments: role);
  }

  Future<void> _allow(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authRepositoryProvider).updatePermissions(cameraPermissionGranted: true);
    } on ApiException {
      // Best-effort — advance regardless, same as "Not Now".
    }
    if (context.mounted) _advance(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PermissionRequestSheet(
      icon: Icons.camera_alt_rounded,
      title: 'Camera Access',
      description: 'Allow camera access to capture and upload photos',
      onAllow: () => _allow(context, ref),
      onSkip: () => _advance(context),
    );
  }
}
