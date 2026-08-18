import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/auth_providers.dart';
import '../../services/permission_service.dart';
import '../../widgets/common/permission_request_sheet.dart';

/// First of three onboarding permission prompts (camera → photo library →
/// push notifications), shown after Complete Profile and before Home /
/// Admin Home.
///
/// "Allow Access" first triggers the real native camera permission
/// dialog via `PermissionService`, then sends `PUT /auth/permissions`
/// with `camera_permission_granted: <result>` (per the backend's own
/// doc-comment: each screen only sends the one flag it owns) so our
/// record matches what the OS actually granted — even if the user
/// dismisses the native dialog with "Deny". "Not Now" skips both the
/// native prompt and the call entirely. Per the brief, both buttons
/// always advance the flow regardless of the outcome, so a denied
/// permission or a failed/slow request never blocks onboarding.
class CameraPermissionScreen extends ConsumerWidget {
  final UserRole? role;
  const CameraPermissionScreen({super.key, this.role});

  void _advance(BuildContext context) {
    Navigator.of(context).pushReplacementNamed(AppRoutes.photoLibraryPermission, arguments: role);
  }

  Future<void> _allow(BuildContext context, WidgetRef ref) async {
    final granted = await PermissionService.instance.checkAndRequestCameraPermission();
    try {
      await ref.read(authRepositoryProvider).updatePermissions(cameraPermissionGranted: granted);
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
