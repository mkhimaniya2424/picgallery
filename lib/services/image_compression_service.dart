import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

/// Downscales and re-encodes image bytes for the Settings > Upload
/// Resolution = "High" option (see settings_model.dart's `uploadQuality`
/// field). Built on the pure-Dart `image` package rather than a
/// platform-channel compressor (e.g. flutter_image_compress) so it works
/// uniformly on web too, matching the rest of the upload pipeline (see
/// the `kIsWeb` branching already throughout upload_queue_provider.dart).
class ImageCompressionService {
  const ImageCompressionService();

  /// Long edge is downscaled to at most this many pixels.
  static const int maxLongEdge = 2048;

  /// Re-encoded as JPEG at this quality (0-100).
  static const int jpegQuality = 85;

  /// Returns [bytes] downscaled to at most [maxLongEdge]px on the long
  /// edge and re-encoded as JPEG at [jpegQuality]% quality. Runs on a
  /// background isolate via [compute] since decode/resize/encode are
  /// CPU-heavy and would otherwise jank the UI thread for large photos.
  ///
  /// Best-effort: if [bytes] can't be decoded as an image (corrupt file,
  /// unsupported format) or the compressed result would actually be
  /// larger than the original, the original [bytes] are returned
  /// unchanged rather than throwing — compression should never be the
  /// reason an upload fails.
  Future<List<int>> compress(List<int> bytes) {
    return compute(_compressSync, Uint8List.fromList(bytes));
  }

  static List<int> _compressSync(Uint8List bytes) {
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    final longEdge =
        decoded.width > decoded.height ? decoded.width : decoded.height;

    img.Image resized = decoded;
    if (longEdge > maxLongEdge) {
      resized = decoded.width >= decoded.height
          ? img.copyResize(decoded, width: maxLongEdge)
          : img.copyResize(decoded, height: maxLongEdge);
    }

    final encoded = img.encodeJpg(resized, quality: jpegQuality);
    return encoded.length < bytes.length ? encoded : bytes;
  }
}
