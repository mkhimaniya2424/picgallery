import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Placeholder interface for sharing media.
///
/// Milestone A constraint: expose method signatures only.
abstract class ShareService {
  Future<void> shareMedia({
    required BuildContext context,
    required String filePath,
  });

  /// Web-safe variant: shares raw [bytes] directly instead of a
  /// filesystem path (web has no `dart:io` File to share).
  Future<void> shareMediaBytes({
    required BuildContext context,
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  });
}
