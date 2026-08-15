import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Service for copying picked files (images/videos) to permanent
/// application documents directory so they survive app restarts.
///
/// Each file is stored under `<app-doc-dir>/media_storage/` with a
/// collision-safe filename.
class FileStorageService {
  static const String _storageSubDir = 'media_storage';

  /// Returns the permanent storage directory, creating it if needed.
  Future<Directory> _getStorageDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final storageDir = Directory('${appDir.path}/$_storageSubDir');
    if (!await storageDir.exists()) {
      await storageDir.create(recursive: true);
    }
    return storageDir;
  }

  /// Generates a collision-safe file path inside the permanent storage
  /// directory. Preserves the original extension and base name, appending
  /// a numeric suffix if a file with the same name already exists.
  Future<String> _resolveUniquePath({
    required Directory storageDir,
    required String fileName,
  }) async {
    final dot = fileName.lastIndexOf('.');
    final base = (dot <= 0) ? fileName : fileName.substring(0, dot);
    final ext =
        (dot <= 0 || dot == fileName.length - 1) ? '' : fileName.substring(dot);

    // Sanitize base name (remove problematic characters)
    final sanitizedBase = base.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

    var candidate = '$sanitizedBase$ext';
    var counter = 1;

    while (await File('${storageDir.path}/$candidate').exists()) {
      candidate = '${sanitizedBase}_$counter$ext';
      counter++;
    }

    return '${storageDir.path}/$candidate';
  }

  /// Copies a file from [sourcePath] to permanent application storage.
  ///
  /// Returns the permanent file path on success.
  /// Throws a [FileStorageException] if the source file is missing or
  /// the copy operation fails.
  ///
  /// [fileName] is used as the basis for the stored filename. If not
  /// provided, the source file's basename is used.
  Future<String> copyToPermanentStorage({
    required String sourcePath,
    String? fileName,
  }) async {
    final source = File(sourcePath);

    // Validate source existence
    if (!await source.exists()) {
      throw FileStorageException(
        'Source file does not exist: $sourcePath',
        FileStorageErrorType.sourceNotFound,
      );
    }

    // Determine filename
    final name = fileName?.isNotEmpty == true
        ? fileName!
        : sourcePath.split(Platform.pathSeparator).last;

    final storageDir = await _getStorageDir();
    final destPath = await _resolveUniquePath(
      storageDir: storageDir,
      fileName: name,
    );

    try {
      await source.copy(destPath);
    } catch (e) {
      throw FileStorageException(
        'Failed to copy file to permanent storage: $e',
        FileStorageErrorType.copyFailed,
      );
    }

    return destPath;
  }

  /// Verifies that a file exists at [path].
  static bool fileExists(String path) {
    if (path.isEmpty) return false;
    final file = File(path);
    return file.existsSync();
  }

  /// Returns the size of the file at [path], or 0 if missing/unreadable.
  static Future<int> fileSize(String path) async {
    if (path.isEmpty) return 0;
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (_) {
      // ignore
    }
    return 0;
  }

  /// Permanently deletes a file from storage. Returns true on success.
  static Future<bool> deletePermanentFile(String path) async {
    if (path.isEmpty) return false;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (_) {
      // ignore
    }
    return false;
  }
}

/// Error type classification for [FileStorageException].
enum FileStorageErrorType {
  sourceNotFound,
  copyFailed,
  unknown,
}

/// Exception thrown by [FileStorageService] operations.
class FileStorageException implements Exception {
  final String message;
  final FileStorageErrorType type;

  const FileStorageException(this.message,
      [this.type = FileStorageErrorType.unknown]);

  @override
  String toString() => 'FileStorageException: $message';
}
