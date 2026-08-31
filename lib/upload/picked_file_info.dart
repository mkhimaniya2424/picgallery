import 'dart:typed_data';

/// Snapshot of a user-picked file, eagerly materialized at pick time.
///
/// file_picker ^12 made [PlatformFile] abstract with async-only accessors
/// ([PlatformFile.readAsBytes], [PlatformFile.length]) that cannot be held
/// in Riverpod state or compared cheaply. This plain data class captures the
/// file metadata (and web bytes, if applicable) once at pick time so the rest
/// of the upload pipeline can remain synchronous and fully testable without
/// any platform channel dependency.
class PickedFileInfo {
  const PickedFileInfo({
    required this.name,
    required this.sizeBytes,
    this.path,
    this.bytes,
    this.extension,
  });

  /// Display name including extension.
  final String name;

  /// File size in bytes (from [PlatformFile.length] at pick time).
  final int sizeBytes;

  /// Local filesystem path, or `null` on web.
  final String? path;

  /// File bytes eagerly loaded on web (`withData: true`); `null` on
  /// native platforms where [path] is used instead.
  final Uint8List? bytes;

  /// Extension without the leading dot (e.g. `'jpg'`, `'mp4'`).
  final String? extension;
}
