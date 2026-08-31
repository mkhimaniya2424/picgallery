import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;

import '../auth/auth_manager.dart';
import '../storage/secure_storage.dart';
import 'auth_interceptor.dart';

/// Thrown whenever the backend responds with a non-2xx status code.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Central API Client powered by [Dio] and [AuthInterceptor] for talking to the
/// PicGallery FastAPI backend. Automatically attaches JWT tokens, handles base URLs,
/// performs automatic 401 token refresh retries, and converts errors into [ApiException].
class ApiClient {
  String baseUrl;
  final Dio _dio;
  final AuthManager? _authManager;
  final SecureStorage? _secureStorage;

  String? _inMemoryToken;

  String? get authToken => _authManager?.accessToken ?? _inMemoryToken;
  set authToken(String? token) {
    _inMemoryToken = token;
    if (_authManager != null && token != null) {
      _authManager!.setTokens(accessToken: token, refreshToken: _authManager!.refreshToken);
    }
  }

  ApiClient({
    String? baseUrl,
    http.Client? client,
    String? authToken,
    AuthManager? authManager,
    SecureStorage? secureStorage,
  })  : baseUrl = baseUrl ?? _defaultBaseUrl(),
        _authManager = authManager,
        _secureStorage = secureStorage,
        _inMemoryToken = authToken,
        _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
        )) {
    if (authToken != null && authManager != null) {
      authManager.setTokens(accessToken: authToken, refreshToken: null);
    }

    final mgr = _authManager ?? AuthManager(secureStorage: _secureStorage);
    final storage = _secureStorage ?? SecureStorage();

    _dio.interceptors.add(
      AuthInterceptor(
        authManager: mgr,
        secureStorage: storage,
        getBaseUrl: () => this.baseUrl,
      ),
    );
  }

  static String baseUrlForHost(String host) {
    final trimmed = host.trim();
    if (trimmed.contains('://')) {
      final withoutTrailingSlash =
          trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
      return withoutTrailingSlash.endsWith('/api/v1')
          ? withoutTrailingSlash
          : '$withoutTrailingSlash/api/v1';
    }
    return 'http://$trimmed:8000/api/v1';
  }

  void updateBaseUrl(String newBaseUrl) => baseUrl = newBaseUrl;

  static String _defaultBaseUrl() {
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return baseUrlForHost('localhost');
    }

    const envHost = String.fromEnvironment('API_HOST');
    if (envHost.isNotEmpty) return baseUrlForHost(envHost);

    return baseUrlForHost('https://api.picgallery.in');
  }

  String _url(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$cleanPath';
  }

  Future<dynamic> get(String path, {bool withAuth = true}) async {
    return _guarded(() => _dio.get(
          _url(path),
          options: Options(extra: {'withAuth': withAuth}),
        ));
  }

  Future<dynamic> post(String path, {Object? body, bool withAuth = true}) async {
    return _guarded(() => _dio.post(
          _url(path),
          data: body,
          options: Options(
            extra: {'withAuth': withAuth},
            headers: {'Content-Type': 'application/json'},
          ),
        ));
  }

  Future<dynamic> put(String path, {Object? body, bool withAuth = true}) async {
    return _guarded(() => _dio.put(
          _url(path),
          data: body,
          options: Options(
            extra: {'withAuth': withAuth},
            headers: {'Content-Type': 'application/json'},
          ),
        ));
  }

  Future<dynamic> patch(String path, {Object? body, bool withAuth = true}) async {
    return _guarded(() => _dio.patch(
          _url(path),
          data: body,
          options: Options(
            extra: {'withAuth': withAuth},
            headers: {'Content-Type': 'application/json'},
          ),
        ));
  }

  Future<dynamic> delete(String path, {Object? body, bool withAuth = true}) async {
    return _guarded(() => _dio.delete(
          _url(path),
          data: body,
          options: Options(
            extra: {'withAuth': withAuth},
            headers: {'Content-Type': 'application/json'},
          ),
        ));
  }

  Future<dynamic> _guarded(Future<Response> Function() send) async {
    try {
      final response = await send();
      return _handleResponse(response);
    } on DioException catch (e) {
      if (e.response != null) {
        return _handleResponse(e.response!);
      }
      throw const ApiException(
        0,
        "Couldn't reach the server. Check your connection and that the backend is running, then try again.",
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        0,
        e.toString(),
      );
    }
  }

  dynamic _handleResponse(Response response) {
    final statusCode = response.statusCode ?? 0;
    final data = response.data;

    if (statusCode >= 200 && statusCode < 300) {
      return data;
    }

    throw ApiException(statusCode, _extractMessage(data, response.statusMessage ?? ''));
  }

  String _extractMessage(dynamic decoded, String rawBody) {
    if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('detail')) {
        final detail = decoded['detail'];
        if (detail is String) return detail;
        if (detail is Map && detail.containsKey('message')) {
          return detail['message'].toString();
        }
        if (detail is List) {
          return detail
              .map((e) => e is Map && e['msg'] != null ? e['msg'].toString() : e.toString())
              .join(', ');
        }
        return detail.toString();
      }
      if (decoded.containsKey('message')) {
        return decoded['message'].toString();
      }
    }
    return rawBody.isNotEmpty ? rawBody : 'Unknown error';
  }

  void dispose() => _dio.close();
}
