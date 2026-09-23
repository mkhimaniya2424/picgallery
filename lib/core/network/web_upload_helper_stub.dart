Future<dynamic> uploadFileWeb({
  required String blobUrl,
  required String uploadUrl,
  required String fileName,
  required String contentType,
  required Map<String, String> headers,
  Function(int, int)? onSendProgress,
}) async {
  throw UnsupportedError('Only supported on Web');
}
