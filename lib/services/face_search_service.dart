import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;

import '../core/network/api_client.dart';
import '../models/face_search_result_model.dart';

class FaceSearchService {
  FaceSearchService({required ApiClient apiClient, http.Client? httpClient})
      : _apiClient = apiClient,
        _httpClient = httpClient ?? http.Client();

  final ApiClient _apiClient;
  final http.Client _httpClient;

  static const Duration _timeout = Duration(minutes: 5);

  Future<FaceSearchApiResponse> search({
    required List<int> bytes,
    required String fileName,
    required String contentType,
    int? faceIndex,
    double? threshold,
    void Function(int sentBytes, int totalBytes)? onSendProgress,
  }) async {
    final query = <String, String>{
      if (faceIndex != null) 'face_index': faceIndex.toString(),
      if (threshold != null) 'threshold': threshold.toString(),
    };
    final path = query.isEmpty
        ? '/client/faces/search'
        : '/client/faces/search?${Uri(queryParameters: query).query}';
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
      throw const ApiException(
        0,
        "Couldn't reach the server. Check your connection and that the backend is running, then try again.",
      );
    }

    final response = await http.Response.fromStream(streamedResponse);
    return _decode(response);
  }

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

  FaceSearchApiResponse _decode(http.Response response) {
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
      return FaceSearchApiResponse.fromJson(decoded);
    }

    throw ApiException(statusCode, _extractMessage(decoded, response.body));
  }

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
