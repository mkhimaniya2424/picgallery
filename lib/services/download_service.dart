import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../core/network/api_client.dart';

/// Placeholder interface for downloading/exporting media.
///
/// Milestone A constraint: expose method signatures only.
abstract class DownloadService {
  /// [mediaId] is the backend id of the media being saved, when the
  /// caller already has it. Pass it whenever available — it lets the
  /// Download History log skip re-deriving the media from [filePath],
  /// which fails for any API-backed (network) media since its cached
  /// local path never matches what's stored locally. See
  /// [DownloadServiceImpl] for details.
  ///
  /// [apiClient] should be the app's single shared, already-logged-in
  /// client (`ref.read(apiClientProvider)`) whenever the caller has a
  /// `WidgetRef` in scope. Without it, Download History logging falls
  /// back to a token read from disk that's only ever there if
  /// "Remember me" was checked at login — see [DownloadServiceImpl].
  /// [isClientUser] must be true when the caller is a logged-in client
  /// account (not a studio) — Download History logging posts to a
  /// different, client-only backend route (`POST /client/download-history`)
  /// since the studio route 403s for client tokens. Defaults to false
  /// (studio) since most call sites are studio-only screens.
  Future<bool> downloadOriginal({
    required BuildContext context,
    required String filePath,
    String? mediaId,
    ApiClient? apiClient,
    bool isClientUser = false,
  });

  Future<bool> downloadEditedCopy({
    required BuildContext context,
    required String filePath,
  });

  /// Web-safe variant: saves raw [bytes] directly instead of reading
  /// them from a filesystem path (web has no `dart:io` File to read).
  Future<bool> downloadBytes({
    required BuildContext context,
    required Uint8List bytes,
    required String fileName,
    String? mediaId,
    ApiClient? apiClient,
    bool isClientUser = false,
  });

  /// Saves the photo/video at [filePath] into the OS-level media
  /// gallery (Photos on iOS, the MediaStore-backed gallery on Android)
  /// instead of a user-picked "save as" location.
  ///
  /// On platforms with no OS gallery concept (web, macOS, Windows,
  /// Linux) this falls back to the same "save as" flow used by
  /// [downloadOriginal].
  Future<bool> saveToGallery({
    required BuildContext context,
    required String filePath,
    String? mediaId,
    ApiClient? apiClient,
    bool isClientUser = false,
  });
}