import '../api/admin_api_client.dart';

/// Turns a list of users (already carrying `.usedBytes`) into a
/// CSV string with a header row. Escapes commas/quotes/newlines in
/// any text field per RFC 4180.
String usersStorageToCsv(List<PlatformUser> users) {
  final buffer = StringBuffer()
    ..writeln('Name,Email,Type,Studio Name,Used Bytes');
  for (final u in users) {
    buffer.writeln([
      _csvField(u.fullName),
      _csvField(u.email),
      _csvField(u.isStudio ? 'Studio' : 'Client'),
      _csvField(u.studioName ?? ''),
      (u.usedBytes ?? 0).toString(),
    ].join(','));
  }
  return buffer.toString();
}

String _csvField(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}
