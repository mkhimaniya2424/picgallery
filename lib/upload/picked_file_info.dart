import 'dart:typed_data';

/// Snapshot of a user-picked file, eagerly materialized at pick time.
///
/// file_picker ^12 made [PlatformFile] abstract with async-only accessors
/// ([PlatformFile.readAsBytes], [PlatformFile.length]) that cannot be held
/// in Riverpod state or compared cheaply. This plain data class captures the
/// file metadata (and web bytes/stream, if applicable) once at pick time so
/// the rest of the upload pipeline can remain synchronous and fully testable
/// without any platform channel dependency.
class PickedFileInfo {
  const PickedFileInfo({
    required this.name,
    required this.sizeBytes,
    this.path,
    this.bytes,
    this.extension,
    this.streamFactory,
    this.webBlobUrl,
  });

  /// Display name including extension.
  final String name;

  /// File size in bytes (from [PlatformFile.length] at pick time).
  final int sizeBytes;

  /// Local filesystem path, or `null` on web.
  final String? path;

  /// File bytes eagerly loaded for small files; `null` for large files on
  /// web where streaming is preferred via [streamFactory].
  final Uint8List? bytes;

  /// Extension without the leading dot (e.g. `'jpg'`, `'mp4'`).
  final String? extension;

  /// Factory that opens a fresh byte stream from the underlying web file.
  /// Only populated on web for large files where eagerly loading bytes
  /// would cause OOM. On native platforms this is always null.
  final Stream<Uint8List> Function()? streamFactory;

  /// Object URL for the picked file (e.g. `blob:http://...`).
  /// Only populated on web. Used to stream large files natively.
  final String? webBlobUrl;

  /// Whether this file has streaming support (web large files).
  bool get hasStream => streamFactory != null || webBlobUrl != null;
}
