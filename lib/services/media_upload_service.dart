import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;





import '../core/network/api_client.dart';
import '../models/media_model.dart';

/// Deliberately NOT a Riverpod provider/notifier (Task 19.5 — "standalone").
/// Takes an [ApiClient] purely to reuse its `baseUrl`/`authToken`, not as
/// a Riverpod dependency — [ApiClient] itself is a plain Dart class with
/// no `ref` in sight, same as `AuthRepository`/`UserRepository`.
///
/// Test this directly before wiring it into `uploadProvider` (Task
/// 19.9) — e.g. a throwaway button:
/// ```dart
/// final service = MediaUploadService(apiClient: ref.read(apiClientProvider));
/// final media = await service.upload(
///   bytes: someBytes,
///   fileName: 'test.jpg',
///   contentType: 'image/jpeg',
///   onSendProgress: (sent, total) => debugPrint('$sent / $total'),
/// );
/// ```
///
/// Talks to `POST /media/upload` (`app/api/routes/media.py`) as a real
/// multipart/form-data request: `file` is the binary part, `album_id`/
/// `folder_id` go on as optional query params — exactly what the
/// backend expects (it is NOT a JSON body, so this can't reuse
/// [ApiClient.post]).
class MediaUploadService {
  MediaUploadService({required ApiClient apiClient, http.Client? httpClient})
      : _apiClient = apiClient,
        _httpClient = httpClient ?? http.Client();

  final ApiClient _apiClient;
  final http.Client _httpClient;

  /// Uploads can be large (photos, and especially videos) and slow on
  /// weak connections, so this gets a much longer budget than
  /// [ApiClient]'s 15s JSON timeout rather than sharing it.
  static const Duration _timeout = Duration(minutes: 5);

  /// Uploads [bytes] as a new media item.
  ///
  /// [fileName] and [contentType] (e.g. `'image/jpeg'`, `'video/mp4'`)
  /// describe the file being sent — the backend uses [contentType] to
  /// decide photo vs. video and rejects anything it doesn't recognize.
  /// [albumId]/[folderId] file the upload directly on arrival; leaving
  /// both null uploads as "unfiled", same as the backend's default.
  ///
  /// [onSendProgress], if given, fires repeatedly as bytes are actually
  /// written to the socket — `(sentBytes, totalBytes)` — so callers can
  /// drive a progress bar. Matches the `(sent, total)` shape already
  /// used by `MediaRepository.uploadMedia`'s `onSendProgress` param, so
  /// Task 19.9 can forward it straight through unchanged.
  ///
  /// Throws [ApiException] on any non-2xx response — 401 (needs
  /// re-login), 413 (file too large), 400 (unsupported content type),
  /// see `upload_media` in `app/api/routes/media.py` — or if the
  /// request can't reach the server at all / times out.
  Future<MediaModel> upload({
    required List<int> bytes,
    required String fileName,
    required String contentType,
    String? albumId,
    String? folderId,
    void Function(int sentBytes, int totalBytes)? onSendProgress,
  }) async {
    final query = <String, String>{
      if (albumId != null) 'album_id': albumId,
      if (folderId != null) 'folder_id': folderId,
    };
    final path =
        query.isEmpty ? '/media/upload' : '/media/upload?${Uri(queryParameters: query).query}';
    final uri = Uri.parse('${_apiClient.baseUrl}$path');

    final request = http.MultipartRequest('POST', uri);
    final token = _apiClient.authToken;
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
contentType: http_parser.MediaType.parse(contentType),
      ),
    );

    final http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await _send(request, onSendProgress).timeout(
        _timeout,
        onTimeout: _throwTimeout,
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      // Any other failure — connection refused, DNS failure, TLS error,
      // the stream erroring mid-flight, etc. — becomes the same
      // [ApiException] shape [ApiClient] already uses, so callers only
      // ever need to catch one exception type.
      throw const ApiException(
        0,
        "Couldn't reach the server. Check your connection and that the backend is running, then try again.",
      );
    }

    final response = await http.Response.fromStream(streamedResponse);
    return _decode(response);
  }

  /// Destructively overwrites [mediaId]'s original file via
  /// `PUT /media/{id}/file` — the photo editor's "Overwrite Original"
  /// action. Same multipart shape/error handling as [upload]; the only
  /// difference is the HTTP method and that there's no album/folder to
  /// place it in, since it's replacing bytes on an existing row rather
  /// than creating a new one.
  Future<MediaModel> replaceFile({
    required String mediaId,
    required List<int> bytes,
    required String fileName,
    required String contentType,
    void Function(int sentBytes, int totalBytes)? onSendProgress,
  }) async {
    final uri = Uri.parse('${_apiClient.baseUrl}/media/$mediaId/file');

    final request = http.MultipartRequest('PUT', uri);
    final token = _apiClient.authToken;
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
        contentType: http_parser.MediaType.parse(contentType),
      ),
    );

    final http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await _send(request, onSendProgress).timeout(
        _timeout,
        onTimeout: _throwTimeout,
      );
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        0,
        "Couldn't reach the server. Check your connection and that the backend is running, then try again.",
      );
    }

    final response = await http.Response.fromStream(streamedResponse);
    return _decode(response);
  }

  /// [http.MultipartRequest] has no built-in progress hook, and its
  /// `contentLength` is only known *after* [http.MultipartRequest.finalize]
  /// computes it — so when a caller wants progress, this finalizes the
  /// request by hand, counts bytes as they flow through the resulting
  /// [http.ByteStream], and re-parcels them into a fresh
  /// [http.StreamedRequest] that carries the same method/URL/headers.
  /// With no listener, it skips all of that and sends [request] as-is.
  Future<http.StreamedResponse> _send(
    http.MultipartRequest request,
    void Function(int sentBytes, int totalBytes)? onSendProgress,
  ) {
    if (onSendProgress == null) {
      return _httpClient.send(request);
    }

    final totalBytes = request.contentLength;
    var sentBytes = 0;

    final progressStream = request.finalize().transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (chunk, sink) {
          sentBytes += chunk.length;
          onSendProgress(sentBytes, totalBytes);
          sink.add(chunk);
        },
      ),
    );

    final streamedRequest = http.StreamedRequest(request.method, request.url)
      ..headers.addAll(request.headers)
      ..contentLength = totalBytes;

    // Fire-and-forget: pipes chunks into the request's sink (and closes
    // it on done / forwards errors) while `_httpClient.send` below reads
    // from the other end concurrently. We don't await this Future
    // ourselves — `send` completing (or erroring) is what the caller
    // actually waits on.
    // ignore: unawaited_futures
    progressStream.pipe(streamedRequest.sink);

    return _httpClient.send(streamedRequest);
  }

  Never _throwTimeout() {
    throw const ApiException(
      0,
      "Couldn't reach the server. Check your connection and that the backend is running, then try again.",
    );
  }

  MediaModel _decode(http.Response response) {
    final statusCode = response.statusCode;

    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }
    }

    if (statusCode >= 200 && statusCode < 300 && decoded is Map<String, dynamic>) {
      return MediaModel.fromApiJson(decoded);
    }

    throw ApiException(statusCode, _extractMessage(decoded, response.body));
  }

  /// Mirrors [ApiClient]'s own (private) message-extraction so FastAPI's
  /// `{"detail": ...}` error shape reads the same regardless of which
  /// class actually made the request.
  String _extractMessage(dynamic decoded, String rawBody) {
    if (decoded is Map<String, dynamic> && decoded.containsKey('detail')) {
      final detail = decoded['detail'];
      if (detail is String) return detail;
      if (detail is List) {
        return detail
            .map((e) => e is Map && e['msg'] != null ? e['msg'].toString() : e.toString())
            .join(', ');
      }
      return detail.toString();
    }
    return rawBody.isNotEmpty ? rawBody : 'Unknown error';
  }

  void dispose() => _httpClient.close();
}
