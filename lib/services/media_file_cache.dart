import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/media_model.dart';

/// Result of a web-safe in-memory fetch via [MediaFileCache.bytesFor].
///
/// Web has no filesystem to cache into, so instead of a path we hand
/// back the raw bytes plus a filename the caller can pass straight to
/// `XFile.fromData` (share) or `file_saver` (download).
class MediaBytesResult {
  const MediaBytesResult({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

/// Resolves a [MediaModel] to a real local file path that the
/// device-local [ShareService]/[DownloadService] implementations can
/// work with — both of those only ever understood `File(filePath)`,
/// never a network URL, which is all API-backed media has in
/// [MediaModel.filePath] (left empty on purpose; see
/// [MediaModel.fromApiJson]).
///
/// For device-local media this is just [MediaModel.displayPath]
/// unchanged. For API-backed media ([MediaModel.isDisplayPathNetwork]),
/// the original file is fetched from the backend once into a per-device
/// cache directory and reused on later calls, instead of re-downloading
/// every time the user taps Share/Save.
class MediaFileCache {
  const MediaFileCache();

  /// Returns a local file path for [media], downloading it first if
  /// it's only available over the network. Returns null if there's
  /// nothing to resolve (no path at all) or the download failed.
  Future<String?> localPathFor(MediaModel media) async {
    if (!media.isDisplayPathNetwork) {
      return media.displayPath.isEmpty ? null : media.displayPath;
    }

    final url = media.displayPath;
    if (url.isEmpty) return null;

    final ext = _extensionFor(
      media.fileName,
      fallback: media.type == MediaType.video ? '.mp4' : '.jpg',
    );
    final cacheDir = Directory('${Directory.systemTemp.path}/gallery_media_cache');
    final file = File('${cacheDir.path}/${media.id}$ext');

    // Reuse what's already been fetched rather than downloading again
    // on every Share/Save tap for the same item.
    if (await file.exists()) return file.path;

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;

      await cacheDir.create(recursive: true);
      await file.writeAsBytes(response.bodyBytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Web-safe counterpart to [localPathFor]. Web has no `dart:io`
  /// filesystem to cache into, so this fetches [media] straight into
  /// memory and returns the raw bytes instead of a path. Returns null
  /// if there's nothing to resolve or the fetch failed.
  Future<MediaBytesResult?> bytesFor(MediaModel media) async {
    final ext = _extensionFor(
      media.fileName,
      fallback: media.type == MediaType.video ? '.mp4' : '.jpg',
    );
    final fileName = media.fileName.isNotEmpty ? media.fileName : '${media.id}$ext';

    if (!media.isDisplayPathNetwork) {
      // Device-local media has no meaning on web (no filesystem), so
      // the only real source of bytes here is a network URL. If we
      // somehow get a non-network path on web there's nothing to fetch.
      return null;
    }

    final url = media.displayPath;
    if (url.isEmpty) return null;

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;
      return MediaBytesResult(bytes: response.bodyBytes, fileName: fileName);
    } catch (_) {
      return null;
    }
  }

  String _extensionFor(String fileName, {required String fallback}) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return fallback;
    return fileName.substring(dot).toLowerCase();
  }
}
