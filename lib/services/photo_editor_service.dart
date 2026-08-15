import 'package:flutter/widgets.dart';

/// Placeholder interface for photo editing.
///
/// Milestone A constraint: expose method signatures only.
abstract class PhotoEditorService {
  /// Validates filePath and returns a user-friendly message if invalid.
  ///
  /// Milestone A does not perform any image processing.
  Future<String?> validateFilePath({
    required BuildContext context,
    required String filePath,
  });

  /// Applies edits and returns output file path.
  ///
  /// Milestone A: not implemented.
  Future<String> renderEditedCopy({
    required BuildContext context,
    required String inputFilePath,
  });
}
