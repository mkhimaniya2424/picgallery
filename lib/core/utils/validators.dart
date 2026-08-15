import 'app_exceptions.dart';

/// Centralized validation rules for Albums & Folder Management.
///
/// Every method returns a human-readable error message (or `null` when
/// valid) so it can double as a standard Flutter `FormFieldValidator`
/// later. Controllers that need to hard-stop a mutation can use the
/// `ensure*` variants, which throw a [ValidationException] instead.
class Validators {
  Validators._();

  static const int minNameLength = 2;
  static const int maxNameLength = 60;
  static const int maxDescriptionLength = 300;

  /// Validates a name (album or folder) for basic shape — required,
  /// length bounds — and, when [existingNames] is supplied, uniqueness
  /// (case-insensitive) among sibling entities. Pass [excludingName] when
  /// validating a rename so the entity doesn't collide with itself.
  static String? validateName(
    String? value, {
    String fieldLabel = 'Name',
    List<String> existingNames = const [],
    String? excludingName,
  }) {
    final trimmed = (value ?? '').trim();

    if (trimmed.isEmpty) {
      return '$fieldLabel is required';
    }
    if (trimmed.length < minNameLength) {
      return '$fieldLabel must be at least $minNameLength characters';
    }
    if (trimmed.length > maxNameLength) {
      return '$fieldLabel must be $maxNameLength characters or fewer';
    }

    final normalized = trimmed.toLowerCase();
    final excluding = excludingName?.trim().toLowerCase();
    final isDuplicate = existingNames.any((n) {
      final other = n.trim().toLowerCase();
      if (excluding != null && other == excluding) return false;
      return other == normalized;
    });
    if (isDuplicate) {
      return 'A ${fieldLabel.toLowerCase()} with this name already exists here';
    }

    return null;
  }

  static String? validateDescription(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.length > maxDescriptionLength) {
      return 'Description must be $maxDescriptionLength characters or fewer';
    }
    return null;
  }

  /// Throws [ValidationException] when [validateName] would return an
  /// error — convenient for controllers that want to hard-stop a
  /// create/rename before touching the repository.
  static String ensureValidName(
    String? value, {
    String fieldLabel = 'Name',
    List<String> existingNames = const [],
    String? excludingName,
  }) {
    final error = validateName(
      value,
      fieldLabel: fieldLabel,
      existingNames: existingNames,
      excludingName: excludingName,
    );
    if (error != null) throw ValidationException(error);
    return value!.trim();
  }

  static String? ensureValidDescription(String? value) {
    final error = validateDescription(value);
    if (error != null) throw ValidationException(error);
    final trimmed = (value ?? '').trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
