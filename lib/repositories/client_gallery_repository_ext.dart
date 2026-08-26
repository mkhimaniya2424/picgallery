/// Extension methods for [ClientGalleryRepository] to support downloads
/// with permission checks and logging.
///
/// These are separate from the base repository interface because:
/// 1. Download involves side-effects (permissions, file I/O) beyond pure API calls
/// 2. The base repository focuses on read-only gallery data
/// 3. Permission handling is Flutter-specific (not relevant to the backend layer)
///
/// Usage: Treat these as repository-level convenience wrappers that coordinate
/// with [DownloadService] — the service handles the actual file save/gallery I/O,
/// while repository methods here handle permission pre-checks and logging framing.

import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../models/media_model.dart';
import '../services/download_service.dart';
import '../services/permission_service.dart';
import 'client_gallery_repository.dart';

extension ClientGalleryDownloads on ApiClientGalleryRepository {
  /// Pre-checks storage permission before attempting to download.
  /// Returns the permission status and handles prompting if needed.
  ///
  /// Callers should respect the returned [Future<bool>]:
  /// - `true` = permission already granted or was just granted
  /// - `false` = user denied or device doesn't support permission
  ///
  /// This runs OUTSIDE the download service's try/catch, so permission
  /// denials bubble up for the caller to handle with snackbars/dialogs
  /// before we ever touch files.
  Future<bool> checkStoragePermissionForDownload() async {
    return PermissionService.instance.checkAndRequestStoragePermission();
  }

  /// Verifies the permission was already granted without re-prompting.
  /// Use this to decide whether to show a download button at all, or
  /// to gate UI state (e.g., disable download during initial load).
  Future<bool> isStoragePermissionGranted() async {
    return PermissionService.instance.isStoragePermissionGranted();
  }

  /// Logs a completed download event for [mediaId] to the backend.
  /// This is the client-side counterpart to studio-side download logging.
  ///
  /// The backend's [POST /client/download-history] endpoint is idempotent
  /// and best-effort, so callers don't need to retry on failure —
  /// a file that was successfully saved locally doesn't become a failure
  /// just because the log entry couldn't be posted.
  ///
  /// [apiClient] should be the shared logged-in client from the app.
  /// If null, falls back to [TokenStorage] (less reliable; only has a
  /// token if "Remember me" was checked at login).
  Future<void> logClientDownload(
    String mediaId, {
    ApiClient? apiClient,
  }) async {
    try {
      final client = apiClient ?? ApiClient();
      try {
        await client.post(
          '/client/download-history',
          body: {'media_id': mediaId},
        );
      } finally {
        if (apiClient == null) client.dispose();
      }
    } catch (_) {
      // Best-effort: silently fail if logging can't happen
      // (file was already saved — don't let logging failure ruin the UX)
    }
  }
}
