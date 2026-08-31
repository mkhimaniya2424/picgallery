import 'package:dio/dio.dart';
import '../auth/auth_manager.dart';
import '../storage/secure_storage.dart';

/// Dio [QueuedInterceptor] implementing automatic 401 access token refresh.
///
/// Features:
/// - Automatically attaches `Authorization: Bearer ACCESS_TOKEN` to Studio requests.
/// - Queues concurrent 401 requests so only ONE token refresh request is sent.
/// - On 401, calls `POST /auth/token/refresh`, updates stored tokens, and retries all queued requests.
/// - Excludes auth endpoints (/login, /register, /token/refresh, /social-login) and public client gallery endpoints.
/// - Triggers session expiration on permanent refresh failure.
class AuthInterceptor extends QueuedInterceptor {
  final AuthManager authManager;
  final SecureStorage secureStorage;
  final String Function() getBaseUrl;
  final Dio refreshDio;

  AuthInterceptor({
    required this.authManager,
    required this.secureStorage,
    required this.getBaseUrl,
    Dio? refreshDio,
  }) : refreshDio = refreshDio ?? Dio();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final withAuth = options.extra['withAuth'] ?? true;
    final isPublicClient = options.path.contains('/public/');

    if (withAuth && !isPublicClient) {
      final token = authManager.accessToken ?? await secureStorage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final options = err.requestOptions;

    final isAuthEndpoint = options.path.contains('/auth/login') ||
        options.path.contains('/auth/register') ||
        options.path.contains('/auth/token/refresh') ||
        options.path.contains('/auth/social-login');
    final isPublicClient = options.path.contains('/public/');
    final isRefreshRequest = options.extra['isRefresh'] == true;

    // Only handle 401 Unauthorized for studio authenticated requests
    if (response?.statusCode != 401 || isAuthEndpoint || isPublicClient || isRefreshRequest) {
      return handler.next(err);
    }

    final refreshToken = authManager.refreshToken ?? await secureStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await authManager.handleSessionExpired();
      return handler.next(err);
    }

    try {
      final baseUrl = getBaseUrl();
      final refreshUrl = baseUrl.endsWith('/api/v1')
          ? '$baseUrl/auth/token/refresh'
          : '$baseUrl/api/v1/auth/token/refresh';

      final refreshResponse = await refreshDio.post(
        refreshUrl,
        data: {'refresh_token': refreshToken},
        options: Options(
          extra: {'isRefresh': true},
          headers: {'Content-Type': 'application/json'},
        ),
      );

      final data = refreshResponse.data as Map<String, dynamic>;
      final newAccessToken = (data['access_token'] ?? data['access']) as String;
      final newRefreshToken = (data['refresh_token'] ?? data['refresh']) as String?;

      await secureStorage.saveAccessToken(newAccessToken);
      if (newRefreshToken != null) {
        await secureStorage.saveRefreshToken(newRefreshToken);
      }
      authManager.setTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken ?? refreshToken,
      );

      // Retry original request with new access token
      options.headers['Authorization'] = 'Bearer $newAccessToken';

      final retryDio = Dio();
      final retriedResponse = await retryDio.fetch(options);
      return handler.resolve(retriedResponse);
    } catch (_) {
      await authManager.handleSessionExpired();
      return handler.next(err);
    }
  }
}
