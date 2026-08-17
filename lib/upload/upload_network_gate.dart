import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../services/network_connectivity_service.dart';

/// Provides the real, device-level connectivity check used by
/// [canUploadNow]. Overridable in tests.
final networkConnectivityServiceProvider =
    Provider<NetworkConnectivityService>(
        (ref) => NetworkConnectivityService());

/// Result of an upload-gate check: whether it's OK to start sending
/// bytes right now, and if not, a user-facing reason so callers can show
/// a clear message instead of silently doing nothing.
class UploadGateResult {
  final bool canUpload;
  final String? reason;

  const UploadGateResult.allowed()
      : canUpload = true,
        reason = null;

  const UploadGateResult.blocked(this.reason) : canUpload = false;
}

/// Single source of truth for "is it OK to upload right now". Every
/// upload entry point (the batch queue in upload_queue_provider.dart and
/// the single-file uploader in upload_provider.dart) calls this instead
/// of each reimplementing the Wi-Fi-only check.
///
/// Reads `settings.wifiOnlyUploads` (the global toggle on the Settings
/// screen — see settings_model.dart / admin_settings_screen.dart). If
/// it's off, uploads are always allowed. If it's on, this checks the
/// device's actual current connection via [NetworkConnectivityService]
/// and only allows the upload while genuinely on Wi-Fi — never silently
/// falling back to mobile data.
Future<UploadGateResult> canUploadNow(Ref ref) async {
  final settings = ref.read(settingsProvider);
  if (!settings.wifiOnlyUploads) {
    return const UploadGateResult.allowed();
  }

  final onWifi =
      await ref.read(networkConnectivityServiceProvider).isOnWifi();
  if (onWifi) {
    return const UploadGateResult.allowed();
  }

  return const UploadGateResult.blocked('Waiting for Wi-Fi to upload');
}
