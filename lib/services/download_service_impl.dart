import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_saver/file_saver.dart';
import 'package:gal/gal.dart';

import 'download_service.dart';
import 'media_picker_service.dart' show MediaContentType;
import '../core/network/api_client.dart';
import '../core/storage/token_storage.dart';
import '../storage/media_local_store.dart';
import '../models/media_model.dart';
import '../models/edit_recipe.dart';

class DownloadServiceImpl implements DownloadService {
  const DownloadServiceImpl();

  Future<bool> _validate(BuildContext context, String filePath) async {
    if (filePath.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File path is not available.')),
        );
      }
      return false;
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File is missing. Please try again.')),
        );
      }
      return false;
    }

    return true;
  }

  Future<bool> _downloadToUserLocation({
    required BuildContext context,
    required String filePath,
  }) async {
    if (!context.mounted) return false;

    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final name = file.uri.pathSegments.last;

    return _saveBytes(
      context: context,
      bytes: bytes,
      fileName: name,
      ext: name.split('.').last,
    );
  }

  /// Shared save step used by both the path-based (mobile/desktop) and
  /// bytes-based (web) download flows once bytes are already in memory.
  /// Returns whether a file was actually written, so callers can decide
  /// whether to log a Download History entry (a user-cancelled save
  /// dialog shouldn't create one).
  Future<bool> _saveBytes({
    required BuildContext context,
    required Uint8List bytes,
    required String fileName,
    required String ext,
  }) async {
    // file_saver will show a save dialog where supported.
    final result = await FileSaver.instance.saveFile(
      name: fileName,
      bytes: bytes,
      // Some platforms also use ext.
      ext: ext,
      // file_saver expects a MimeType; leaving it unspecified can fail type checks
      // on newer SDKs, so we pass null only if the API allows it.
      // Here we omit mimeType parameter entirely to keep compatibility.
    );

    // file_saver (^0.2.14) returns a non-nullable String (the saved
    // path/identifier). An empty result is treated as "nothing saved".
    if (result.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download cancelled.')),
        );
      }
      return false;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved successfully.')),
      );
    }
    return true;
  }

  /// Shared Download History step for every "the file is now saved
  /// somewhere" path — `downloadOriginal`/`downloadBytes`'s "Save As"
  /// flow and `saveToGallery`'s native-gallery flow alike — so both show
  /// up in Download History the same way.
  ///
  /// Posts `POST /download-history` (`DownloadEventCreate` in
  /// `app/schemas/gallery.py`), which only needs the backend `media_id`;
  /// the server fills in file name/size/type itself from its own Media
  /// row and the response the history screen reads back
  /// (`GET /download-history`) is parsed by
  /// [DownloadHistoryModel.fromApiJson].
  ///
  /// [apiClient], when supplied, is the app's single already-logged-in
  /// client (`apiClientProvider`) — reusing it is what fixes the
  /// "download works but never shows up in history" gap: that client's
  /// in-memory `authToken` is set on every login regardless of whether
  /// "Remember me" was checked, while [TokenStorage] only ever gets a
  /// token written to it *when Remember me was on* (see
  /// `AuthRepository._persistToken` — it's actively cleared otherwise).
  /// A fresh, TokenStorage-only client here would silently no-op for
  /// any session that unchecked Remember me, even though the user is
  /// demonstrably logged in and every other request is working fine.
  ///
  /// Deliberately best-effort and silent: this runs *after* the save
  /// already succeeded, so a media item that can't be resolved to a
  /// backend id (e.g. a device-local file never uploaded), being logged
  /// out, or the request failing outright must never surface as a save
  /// failure — the user's file is already safely saved either way.
  Future<void> _recordDownloadHistory({
    String? filePath,
    String? fileName,
    String? mediaId,
    ApiClient? apiClient,
    bool isClientUser = false,
  }) async {
    // Studios log to the studio-only `/download-history`; clients must
    // log to the client-only `/client/download-history` instead — the
    // studio route 403s for a client token, which is exactly why client
    // downloads were never showing up in Download History before.
    final endpoint = isClientUser ? '/client/download-history' : '/download-history';
    try {
      // Prefer the id the caller already knows about. The file-based
      // lookup below only exists for call sites that never had a
      // MediaModel in hand to begin with, and it silently fails for
      // any network-backed media anyway (its cached temp path never
      // matches what's stored in MediaLocalStore) — that mismatch is
      // exactly why Download History entries were going missing for
      // downloads of server-hosted photos/videos.
      String? resolvedId = mediaId;
      if (resolvedId == null || resolvedId.isEmpty) {
        final media = await _findMediaFor(filePath: filePath, fileName: fileName);
        if (media == null) return;
        resolvedId = media.id;
      }

      if (apiClient != null) {
        if (apiClient.authToken == null) return;
        await apiClient.post(endpoint, body: {'media_id': resolvedId});
        return;
      }

      // Fallback path for any caller that hasn't been updated to pass
      // the shared client yet. ApiClient() now always resolves to a real
      // backend URL by default, so no saved host lookup is needed — this
      // still depends on TokenStorage having a token, which is the exact
      // gap the [apiClient] path above exists to avoid.
      final token = await TokenStorage().readToken();
      if (token == null) return;

      final fallbackClient = ApiClient(authToken: token);
      try {
        await fallbackClient.post(endpoint, body: {'media_id': resolvedId});
      } finally {
        fallbackClient.dispose();
      }
    } catch (_) {
      // Best-effort logging only — see doc comment above.
    }
  }

  /// Looks up the [MediaModel] a save was performed against, so
  /// [_recordDownloadHistory] has a backend `media_id` to post. Matches
  /// by [filePath] (the path-based downloadOriginal/saveToGallery calls)
  /// or, failing that, by [fileName] (downloadBytes' web-only, bytes-only
  /// calls, which never have a local path to match on).
  Future<MediaModel?> _findMediaFor({String? filePath, String? fileName}) async {
    final store = MediaLocalStore();
    final all = await store.load();

    if (filePath != null && filePath.isNotEmpty) {
      for (final m in all) {
        if (m.filePath == filePath) return m;
      }
    }
    if (fileName != null && fileName.isNotEmpty) {
      for (final m in all) {
        if (m.fileName == fileName) return m;
      }
    }
    return null;
  }

  @override
  Future<bool> downloadOriginal({
    required BuildContext context,
    required String filePath,
    String? mediaId,
    ApiClient? apiClient,
    bool isClientUser = false,
  }) async {
    try {
      if (!await _validate(context, filePath)) return false;
      if (!context.mounted) return false;

      final saved = await _downloadToUserLocation(context: context, filePath: filePath);
      if (saved) {
        await _recordDownloadHistory(
          filePath: filePath,
          mediaId: mediaId,
          apiClient: apiClient,
          isClientUser: isClientUser,
        );
        return true;
      }
      return false;
    } on UnsupportedError {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saving is not supported on this platform.'),
          ),
        );
      }
      return false;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
      return false;
    }
  }

  @override
  Future<bool> downloadBytes({
    required BuildContext context,
    required Uint8List bytes,
    required String fileName,
    String? mediaId,
    ApiClient? apiClient,
    bool isClientUser = false,
  }) async {
    try {
      if (!context.mounted) return false;
      final ext = fileName.contains('.') ? fileName.split('.').last : '';
      final saved = await _saveBytes(
        context: context,
        bytes: bytes,
        fileName: fileName,
        ext: ext,
      );
      if (saved) {
        await _recordDownloadHistory(
          fileName: fileName,
          mediaId: mediaId,
          apiClient: apiClient,
          isClientUser: isClientUser,
        );
        return true;
      }
      return false;
    } on UnsupportedError {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saving is not supported on this platform.'),
          ),
        );
      }
      return false;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
      return false;
    }
  }

  /// `gal` (Photos/MediaStore) only has a concept of a "gallery" on
  /// iOS/Android. Everywhere else — web, macOS, Windows, Linux — there
  /// is no OS gallery to write into, so those platforms reuse the
  /// existing file_saver "save as" flow instead.
  bool get _hasNativeGallery {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  @override
  Future<bool> saveToGallery({
    required BuildContext context,
    required String filePath,
    String? mediaId,
    ApiClient? apiClient,
    bool isClientUser = false,
  }) async {
    try {
      if (!await _validate(context, filePath)) return false;
      if (!context.mounted) return false;

      if (!_hasNativeGallery) {
        final saved = await _downloadToUserLocation(context: context, filePath: filePath);
        if (saved) {
          await _recordDownloadHistory(
            filePath: filePath,
            mediaId: mediaId,
            apiClient: apiClient,
            isClientUser: isClientUser,
          );
          return true;
        }
        return false;
      }

      final fileName = File(filePath).uri.pathSegments.last;
      final mimeType = MediaContentType.forFileName(fileName);
      final isVideo = mimeType.startsWith('video/');

      // Album-scoped access (`toAlbum: true`) is what `putVideo`/`putImage`
      // need under the hood; requesting/checking with the same flag keeps
      // the permission check consistent with the save call below.
      var hasAccess = await Gal.hasAccess(toAlbum: isVideo);
      if (!hasAccess) {
        hasAccess = await Gal.requestAccess(toAlbum: isVideo);
      }
      if (!hasAccess) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gallery permission was denied.'),
            ),
          );
        }
        return false;
      }

      if (isVideo) {
        await Gal.putVideo(filePath);
      } else {
        await Gal.putImage(filePath);
      }

      await _recordDownloadHistory(
        filePath: filePath,
        mediaId: mediaId,
        apiClient: apiClient,
        isClientUser: isClientUser,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to gallery.')),
        );
      }
      return true;
    } on GalException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save to gallery: ${e.type.message}')),
        );
      }
      return false;
    } on UnsupportedError {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saving is not supported on this platform.'),
          ),
        );
      }
      return false;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save to gallery: $e')),
        );
      }
      return false;
    }
  }

  @override
  Future<bool> downloadEditedCopy({
    required BuildContext context,
    required String filePath,
  }) async {
    try {
      final store = MediaLocalStore();
      final mediaList = await store.load();
      final media = mediaList.cast<MediaModel?>().firstWhere(
            (m) => m?.filePath == filePath,
            orElse: () => null,
          );

      if (media == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Media item metadata not found.')),
          );
        }
        return false;
      }

      final recipe = media.editRecipe;
      if (recipe == null || !recipe.hasEdits) {
        // No edits to apply — download the original directly!
        if (!context.mounted) return false;
        return await downloadOriginal(context: context, filePath: filePath);
      }

      // Load source file
      final sourceFile = File('$filePath.original').existsSync()
          ? File('$filePath.original')
          : File(filePath);

      if (!sourceFile.existsSync()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Source image is missing.')),
          );
        }
        return false;
      }

      // Decode the raw image
      final bytes = await sourceFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final double origW = image.width.toDouble();
      final double origH = image.height.toDouble();

      double rotatedW = origW;
      double rotatedH = origH;
      if (recipe.rotation == 90 || recipe.rotation == 270) {
        rotatedW = origH;
        rotatedH = origW;
      }

      final double cropL = recipe.cropLeft * rotatedW;
      final double cropT = recipe.cropTop * rotatedH;
      final double cropR = recipe.cropRight * rotatedW;
      final double cropB = recipe.cropBottom * rotatedH;

      final int targetW = (cropR - cropL).round().clamp(1, rotatedW.round());
      final int targetH = (cropB - cropT).round().clamp(1, rotatedH.round());

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Center crop transform offset
      canvas.translate(-cropL, -cropT);

      // Rotate and flip around center
      canvas.translate(rotatedW / 2, rotatedH / 2);
      canvas.rotate(recipe.rotation * math.pi / 180);
      canvas.scale(recipe.flipHorizontal ? -1.0 : 1.0, recipe.flipVertical ? -1.0 : 1.0);
      canvas.translate(-origW / 2, -origH / 2);

      final paint = Paint();
      final hasColorEdits = recipe.hasEdits && (
        recipe.brightness != 0.0 ||
        recipe.contrast != 0.0 ||
        recipe.saturation != 0.0 ||
        recipe.exposure != 0.0 ||
        recipe.temperature != 0.0 ||
        (recipe.filter != null && recipe.filter != 'none')
      );
      final colorMatrix = hasColorEdits ? recipe.combinedColorMatrix : null;

      if (recipe.sharpen > 0.0) {
        // Draw base image with (1 + sharpen) scale
        final sharpenMatrix = [
          1.0 + recipe.sharpen, 0.0, 0.0, 0.0, 0.0,
          0.0, 1.0 + recipe.sharpen, 0.0, 0.0, 0.0,
          0.0, 0.0, 1.0 + recipe.sharpen, 0.0, 0.0,
          0.0, 0.0, 0.0, 1.0, 0.0,
        ];
        final combinedOriginalMatrix = colorMatrix != null 
            ? EditRecipe.multiplyMatrices(sharpenMatrix, colorMatrix)
            : sharpenMatrix;
            
        final originalPaint = Paint()..colorFilter = ColorFilter.matrix(combinedOriginalMatrix);
        canvas.drawImage(image, Offset.zero, originalPaint);
        
        // Draw blurred image with -sharpen scale
        final blurMatrix = [
          -recipe.sharpen, 0.0, 0.0, 0.0, 0.0,
          0.0, -recipe.sharpen, 0.0, 0.0, 0.0,
          0.0, 0.0, -recipe.sharpen, 0.0, 0.0,
          0.0, 0.0, 0.0, 1.0, 0.0,
        ];
        final combinedBlurMatrix = colorMatrix != null 
            ? EditRecipe.multiplyMatrices(blurMatrix, colorMatrix)
            : blurMatrix;
            
        final blurPaint = Paint()
          ..imageFilter = ui.ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5, tileMode: TileMode.clamp)
          ..colorFilter = ColorFilter.matrix(combinedBlurMatrix)
          ..blendMode = BlendMode.plus;
        canvas.drawImage(image, Offset.zero, blurPaint);
      } else {
        if (colorMatrix != null) {
          paint.colorFilter = ColorFilter.matrix(colorMatrix);
        }
        canvas.drawImage(image, Offset.zero, paint);
      }

      final picture = recorder.endRecording();
      final renderedImage = await picture.toImage(targetW, targetH);
      final byteData = await renderedImage.toByteData(format: ui.ImageByteFormat.png);
      final renderedBytes = byteData!.buffer.asUint8List();

      final fileName = sourceFile.uri.pathSegments.last;
      final baseName = fileName.contains('.') ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName;

      final result = await FileSaver.instance.saveFile(
        name: 'edited_$baseName',
        bytes: renderedBytes,
        ext: 'png',
      );

      if (result.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Download cancelled.')),
          );
        }
        return false;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved edited copy successfully.')),
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save edited copy: $e')),
        );
      }
      return false;
    }
  }
}