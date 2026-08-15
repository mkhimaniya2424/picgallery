import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;

import '../core/network/api_client.dart';

/// One image in a studio's own Showcase Portfolio grid — mirrors
/// `StudioPortfolioImageRead` in `app/schemas/studio.py`. Distinct from
/// the plain `String` urls in `StudioModel.galleryUrls` (the read-only
/// view a *client* sees) because the studio editing its own profile
/// needs the image's [id] too, in order to delete it later.
class StudioPortfolioImage {
  final String id;
  final String url;

  const StudioPortfolioImage({required this.id, required this.url});

  factory StudioPortfolioImage.fromApiJson(Map<String, dynamic> json) {
    return StudioPortfolioImage(
      id: json['id'] as String,
      url: json['url'] as String,
    );
  }
}

/// Multipart client for a studio uploading its own logo, cover photo, or
/// a Showcase Portfolio image — `POST /studios/me/avatar`, `POST
/// /studios/me/cover`, `POST /studios/me/portfolio`
/// (`app/api/routes/studios.py`). Mirrors [MediaUploadService]'s shape
/// (same not-a-provider, `ApiException`-on-failure pattern) since these
/// are all real `multipart/form-data` requests, not JSON bodies, so
/// none of them can go through [ApiClient.post].
class StudioMediaUploadService {
  StudioMediaUploadService({required ApiClient apiClient, http.Client? httpClient})
      : _apiClient = apiClient,
        _httpClient = httpClient ?? http.Client();

  final ApiClient _apiClient;
  final http.Client _httpClient;

  static const Duration _timeout = Duration(minutes: 5);

  /// Uploads/replaces the studio's logo. Returns the new `avatar_url`
  /// (never null on success — the backend only returns 2xx once it has
  /// actually set the field).
  Future<String?> uploadAvatar({
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) async {
    final decoded = await _upload(path: '/studios/me/avatar', bytes: bytes, fileName: fileName, contentType: contentType);
    return decoded['avatar_url'] as String?;
  }

  /// Uploads/replaces the studio's cover photo. Returns the new
  /// `cover_image_url`.
  Future<String?> uploadCover({
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) async {
    final decoded = await _upload(path: '/studios/me/cover', bytes: bytes, fileName: fileName, contentType: contentType);
    return decoded['cover_image_url'] as String?;
  }

  /// Adds one image to the studio's Showcase Portfolio grid.
  Future<StudioPortfolioImage> uploadPortfolioImage({
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) async {
    final decoded = await _upload(path: '/studios/me/portfolio', bytes: bytes, fileName: fileName, contentType: contentType);
    return StudioPortfolioImage.fromApiJson(decoded);
  }

  /// Shared multipart POST — same shape as [MediaUploadService.upload],
  /// minus the send-progress plumbing (these are small profile images,
  /// not gallery photos/videos, so a progress bar isn't worth the
  /// complexity here).
  Future<Map<String, dynamic>> _upload({
    required String path,
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) async {
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
      streamedResponse = await _httpClient.send(request).timeout(
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

  Never _throwTimeout() {
    throw const ApiException(
      0,
      "Couldn't reach the server. Check your connection and that the backend is running, then try again.",
    );
  }

  Map<String, dynamic> _decode(http.Response response) {
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
      return decoded;
    }

    throw ApiException(statusCode, _extractMessage(decoded, response.body));
  }

  /// Mirrors [MediaUploadService]'s own (private) message-extraction so
  /// FastAPI's `{"detail": ...}` error shape reads the same regardless
  /// of which class actually made the request.
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