/// Shared exception types thrown by repositories/providers when a
/// mutation can't be applied. Kept generic (not tied to Albums or
/// Folders specifically) so any future entity can reuse them.
library;

/// Thrown when user-entered data fails validation (empty name,
/// duplicate name, name too long, invalid move target, etc.).
class ValidationException implements Exception {
  final String message;
  const ValidationException(this.message);

  @override
  String toString() => message;
}

/// Thrown when an operation references an id that no longer exists
/// (e.g. updating/deleting an album or folder that was already removed).
class NotFoundException implements Exception {
  final String message;
  const NotFoundException(this.message);

  @override
  String toString() => message;
}
