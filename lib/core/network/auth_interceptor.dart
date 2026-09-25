import 'package:dio/dio.dart';
import '../auth/auth_manager.dart';
import '../storage/secure_storage.dart';

/// Dio [QueuedInterceptor] implementing automatic 401 access token refresh.
///
/// Features:
/// - Automatically attaches `Authorization: Bearer ACCESS_TOKEN` to requests where withAuth is true.
/// - Queues concurrent 401 requests so only ONE token refresh request is sent.
/// - On 401, calls `POST /auth/token/refresh`, updates stored tokens, and retries all queued requests.
/// - Excludes auth endpoints (/login, /register, /token/refresh, /social-login) and public client gallery endpoints from 401 retry.
/// - Triggers session expiration on permanent refresh failure.
class AuthInterceptor extends QueuedInterceptor {
  final AuthManager authManager;
  final SecureStorage secureStorage;
  final String Function() getBaseUrl;
  final Dio refreshDio;
  /// Optional callback invoked whenever a token refresh succeeds, so callers
  /// (e.g. [ApiClient]) can update their own timestamp bookkeeping.
  final void Function()? onTokenRefreshed;

  AuthInterceptor({
    required this.authManager,
    required this.secureStorage,
    required this.getBaseUrl,
    Dio? refreshDio,
    this.onTokenRefreshed,
  }) : refreshDio = refreshDio ?? Dio();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final withAuth = options.extra['withAuth'] ?? true;

    // Attach the Bearer token only when withAuth is true AND a token exists.
    // Previously this also checked `!isPublicClient`, which caused /public/
    // endpoints to never receive auth even when the caller explicitly set
    // withAuth: true — breaking owner/client access on client-restricted
    // share links (the backend's get_optional_current_user returns None,
    // so _assert_client_authorized raised 403 for the gallery's own owner).
    if (withAuth) {
      final token =
          authManager.accessToken ?? await secureStorage.getAccessToken();
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
    if (response?.statusCode != 401 ||
        isAuthEndpoint ||
        isPublicClient ||
        isRefreshRequest) {
      return handler.next(err);
    }

    final refreshToken =
        authManager.refreshToken ?? await secureStorage.getRefreshToken();
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
      final newRefreshToken =
          (data['refresh_token'] ?? data['refresh']) as String?;

      await secureStorage.saveAccessToken(newAccessToken);
      if (newRefreshToken != null) {
        await secureStorage.saveRefreshToken(newRefreshToken);
      }
      authManager.setTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken ?? refreshToken,
      );
      onTokenRefreshed?.call();

      // If the original request was a FormData (like a file upload), its
      // internal streams/files have likely already been consumed. Retrying
      // it directly via fetch() will throw a StateError, which would previously
      // get caught by the catch block below and log the user out.
      // Instead, we just pass the original 401 error through. The caller
      // (e.g. UploadQueueController) should handle the failure and retry
      // the job with the new token.
      if (options.data is FormData) {
        return handler.next(err);
      }

      // Retry original request with new access token
      options.headers['Authorization'] = 'Bearer $newAccessToken';

      final retryDio = Dio();
      final retriedResponse = await retryDio.fetch(options);
      return handler.resolve(retriedResponse);
    } on DioException catch (e) {
      // Only expire the session if the refresh token itself is rejected (401/403).
      // A timeout (0) or server error (502) should just fail the current
      // request so the user can retry later, without wiping their login state.
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        await authManager.handleSessionExpired();
      }
      return handler.next(err);
    } catch (_) {
      // Some non-Dio error occurred (e.g. parsing error). Don't log out.
      return handler.next(err);
    }
  }
}
