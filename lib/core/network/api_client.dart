import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;

/// Thrown whenever the backend responds with a non-2xx status code.
///
/// [statusCode] is the raw HTTP status code and [message] is the human
/// readable error extracted from FastAPI's `HTTPException` payload
/// (the `detail` field), falling back to the raw response body when the
/// payload isn't in the shape we expect (e.g. a 500 with an HTML body,
/// or a 422 validation error whose `detail` is a list of field errors).
class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thin wrapper around [http] for talking to the picgallery FastAPI
/// backend. Handles base-URL selection per-platform, JSON encoding /
/// decoding, attaching the bearer token when one is available, and
/// turning non-2xx responses into a typed [ApiException].
class ApiClient {
  /// Mutable (not `final`) so [updateBaseUrl] can repoint every future
  /// request at a new host live, without recreating this instance or
  /// restarting the app — see `ServerSettingsSheet` on the splash screen.
  String baseUrl;
  final http.Client _client;

  /// The current access token, if the user is logged in. Set this after
  /// login/register (and clear it on logout) so subsequent requests are
  /// authenticated automatically.
  String? authToken;

  ApiClient({String? baseUrl, http.Client? client, this.authToken})
      : baseUrl = baseUrl ?? _defaultBaseUrl(),
        _client = client ?? http.Client();

  /// Sentinel `baseUrl` used only when no real host could be determined —
  /// see [_defaultBaseUrl]. Deliberately not a URL scheme any real request
  /// could ever reach; [isConfigured] checks against this directly so a
  /// misconfigured client fails loudly (a clear [ApiException] — see
  /// [_guarded]) instead of silently dialing a dead LAN IP forever.
  static const String _unconfiguredBaseUrl = 'unconfigured://no-server-set';

  /// False only on a real device/emulator that has neither an `API_HOST`
  /// build-time override nor a host saved via [ServerConfigStorage] /
  /// the gear-icon [ServerSettingsSheet]. Desktop/web are always
  /// considered configured (they use `localhost` — see [_defaultBaseUrl]).
  bool get isConfigured => baseUrl != _unconfiguredBaseUrl;

  /// Builds a full base URL from either just a host/IP (e.g.
  /// `192.168.1.34`, kept on the default `http://…:8000/api/v1` shape) or
  /// an already-complete URL (e.g. a Cloudflare Tunnel/ngrok URL like
  /// `https://my-tunnel.trycloudflare.com`, which is typically already on
  /// port 443 with its own scheme and shouldn't have `:8000` forced onto
  /// it). Used by both [_defaultBaseUrl]'s `API_HOST` override and
  /// [ServerSettingsSheet]'s manual entry.
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

  /// Repoints this client at a new host immediately — no app restart or
  /// provider rebuild required, since every request reads `baseUrl` at
  /// call time via [_uri]. Callers should also persist the host via
  /// [ServerConfigStorage] so it survives the next launch too.
  void updateBaseUrl(String newBaseUrl) => baseUrl = newBaseUrl;

  /// `10.0.2.2` is how the Android emulator reaches the host machine's
  /// `localhost`; everything else (iOS simulator, web, desktop) can use
  /// `localhost` directly.
  static String _defaultBaseUrl() {
    // Web (Chrome debugging) and desktop run on the SAME machine as the
    // backend, so they can always reach it at localhost — no IP needed,
    // ever, regardless of which network the PC is on. This is the one
    // case that genuinely never needs updating. `kIsWeb` is checked
    // first (and short-circuits) because `defaultTargetPlatform` alone
    // can't distinguish "web" from the OS it happens to be running in.
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return baseUrlForHost('localhost');
    }

    // A REAL phone (or emulator) is a separate device from the backend,
    // so there is no address that's correct by default the way
    // `localhost` is above — a hardcoded LAN IP here only ever works from
    // the one Wi-Fi network it was written on and silently fails
    // everywhere else (mobile data, a different Wi-Fi, another dev's
    // machine, ...). Instead:
    //  1. `--dart-define=API_HOST=<host-or-full-url>` lets a build pin a
    //     host (or a persistent tunnel URL, e.g. Cloudflare Tunnel/ngrok)
    //     without hardcoding it in source.
    //  2. Otherwise, this stays deliberately unconfigured — see
    //     [isConfigured] — until the gear icon on the sign-in screen
    //     ([ServerSettingsSheet]) sets and persists one via
    //     [ServerConfigStorage] (read back in `main.dart` on next
    //     launch). Every request made while unconfigured fails fast with
    //     a clear [ApiException] (see [_guarded]) instead of hanging on
    //     a dead IP.
    const envHost = String.fromEnvironment('API_HOST');
    if (envHost.isNotEmpty) return baseUrlForHost(envHost);

    return _unconfiguredBaseUrl;
  }
  Map<String, String> _headers({bool withAuth = true}) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (withAuth && authToken != null) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    return headers;
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// No request should hang forever — if the backend (or the phone's
  /// network path to it) is unreachable, this turns that into a clean
  /// [ApiException] after 15s instead of leaving callers' `_isLoading`
  /// spinners stuck on an unresolved Future indefinitely (e.g. Forgot
  /// Password's "Send Reset Link" button hanging with no error at all).
  static const Duration _timeout = Duration(seconds: 15);

  Future<dynamic> get(String path, {bool withAuth = true}) async {
    final response = await _guarded(() => _client
        .get(_uri(path), headers: _headers(withAuth: withAuth))
        .timeout(_timeout, onTimeout: _throwTimeout));
    return _handleResponse(response);
  }

  Future<dynamic> post(String path, {Object? body, bool withAuth = true}) async {
    final response = await _guarded(() => _client
        .post(
          _uri(path),
          headers: _headers(withAuth: withAuth),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(_timeout, onTimeout: _throwTimeout));
    return _handleResponse(response);
  }

  Future<dynamic> put(String path, {Object? body, bool withAuth = true}) async {
    final response = await _guarded(() => _client
        .put(
          _uri(path),
          headers: _headers(withAuth: withAuth),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(_timeout, onTimeout: _throwTimeout));
    return _handleResponse(response);
  }

  /// Used by PATCH /users/me (partial profile update, Task 5/7) — the
  /// only PATCH endpoint the backend exposes so far.
  Future<dynamic> patch(String path, {Object? body, bool withAuth = true}) async {
    final response = await _guarded(() => _client
        .patch(
          _uri(path),
          headers: _headers(withAuth: withAuth),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(_timeout, onTimeout: _throwTimeout));
    return _handleResponse(response);
  }

  /// Used by DELETE /users/me (Task 10 — Delete Account). `body` carries
  /// the password confirmation; `http.Client.delete` supports a body the
  /// same way post/put/patch do, it's just rarely used.
  Future<dynamic> delete(String path, {Object? body, bool withAuth = true}) async {
    final response = await _guarded(() => _client
        .delete(
          _uri(path),
          headers: _headers(withAuth: withAuth),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(_timeout, onTimeout: _throwTimeout));
    return _handleResponse(response);
  }

  /// Every request goes through here so that ANY failure — timeout,
  /// connection refused, DNS lookup failure, TLS error, etc. — comes
  /// out the other side as an [ApiException]. Without this, a raw
  /// [SocketException] (e.g. the backend simply isn't running) would
  /// propagate past callers' `on ApiException catch (e)` blocks
  /// entirely, leaving their `_isLoading` flag stuck at `true` forever
  /// with no error shown — the exact "stuck spinner" symptom.
  Future<http.Response> _guarded(Future<http.Response> Function() send) async {
    if (!isConfigured) {
      throw const ApiException(
        0,
        "No backend server is set up yet. Tap the gear icon on the sign-in "
        "screen and enter your backend's host, IP, or tunnel URL (e.g. from "
        "ngrok or Cloudflare Tunnel).",
      );
    }
    try {
      return await send();
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        0,
        "Couldn't reach the server. Check your connection and that the backend is running, then try again.",
      );
    }
  }

  Never _throwTimeout() {
    throw const ApiException(
      0,
      "Couldn't reach the server. Check your connection and that the backend is running, then try again.",
    );
  }

  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;

    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }
    }

    if (statusCode >= 200 && statusCode < 300) {
      return decoded;
    }

    throw ApiException(statusCode, _extractMessage(decoded, response.body));
  }

  /// FastAPI's `HTTPException(detail: str)` produces `{"detail": "..."}`.
  /// Pydantic validation errors (422) instead produce
  /// `{"detail": [{"loc": [...], "msg": "...", "type": "..."}]}`, so we
  /// join those into a readable string. Anything else falls back to the
  /// raw body.
  String _extractMessage(dynamic decoded, String rawBody) {
    if (decoded is Map<String, dynamic> && decoded.containsKey('detail')) {
      final detail = decoded['detail'];
      if (detail is String) {
        return detail;
      }
      if (detail is List) {
        return detail
            .map((e) => e is Map && e['msg'] != null ? e['msg'].toString() : e.toString())
            .join(', ');
      }
      return detail.toString();
    }
    return rawBody.isNotEmpty ? rawBody : 'Unknown error';
  }

  void dispose() => _client.close();
}