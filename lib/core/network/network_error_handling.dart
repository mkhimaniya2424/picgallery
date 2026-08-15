import 'package:flutter/material.dart';

import 'api_client.dart';
import '../../core/routes/app_routes.dart';

/// High-level actions to take after an error.
enum NetworkErrorAction {
  /// Force user to sign in again.
  relogin,

  /// Retry the failed operation.
  retry,

  /// No global action.
  none,
}

/// User-facing description + suggested UI behaviour.
class NetworkErrorView {
  final String title;
  final String message;
  final NetworkErrorAction action;
  final bool showCachedDataBanner;

  const NetworkErrorView({
    required this.title,
    required this.message,
    required this.action,
    required this.showCachedDataBanner,
  });
}

/// Central mapping from low-level network/backend errors to
/// user-facing UI instructions.
///
/// Rules (Task 19.13):modelOpmodel
/// - 401 → re-login
/// - 5xx → retry
/// - offline → show cached data banner
NetworkErrorView mapNetworkError(Object error, {String? fallbackMessage}) {
  const offlineMessage = "You're offline — showing cached data.";
  const defaultServerMessage = 'Something went wrong. Please try again.';

  // 401 (auth) + 5xx (server) are represented by ApiException.
  if (error is ApiException) {
    final sc = error.statusCode;

    if (sc == 401) {
      return const NetworkErrorView(
        title: 'Session expired',
        message: 'Please sign in again to continue.',
        action: NetworkErrorAction.relogin,
        showCachedDataBanner: false,
      );
    }

    if (sc >= 500 && sc < 600) {
      return NetworkErrorView(
        title: 'Server error',
        message: (fallbackMessage != null && fallbackMessage.isNotEmpty)
            ? fallbackMessage
            : (error.message.isNotEmpty ? error.message : defaultServerMessage),
        action: NetworkErrorAction.retry,
        showCachedDataBanner: false,
      );
    }

    // Any other non-2xx: still prefer a retry-ish fallback for most users.
    if (error.message.isNotEmpty) {
      return NetworkErrorView(
        title: 'Request failed',
        message: error.message,
        action: NetworkErrorAction.retry,
        showCachedDataBanner: false,
      );
    }

    return NetworkErrorView(
      title: 'Request failed',
      message: fallbackMessage ?? defaultServerMessage,
      action: NetworkErrorAction.retry,
      showCachedDataBanner: false,
    );
  }

  // Offline/reachability: ApiClient uses ApiException(statusCode: 0, message: ...)
  // for timeouts/connection failures.
  if (error is ApiException && error.statusCode == 0) {
    return const NetworkErrorView(
      title: 'No connection',
      message: offlineMessage,
      action: NetworkErrorAction.none,
      showCachedDataBanner: true,
    );
  }

  // Best-effort heuristic for common offline objects.
  final s = error.toString().toLowerCase();
  final looksOffline = s.contains('couldn\'t reach the server') ||
      s.contains('no internet') ||
      s.contains('socketexception') ||
      s.contains('timeout');

  if (looksOffline) {
    return const NetworkErrorView(
      title: 'No connection',
      message: offlineMessage,
      action: NetworkErrorAction.none,
      showCachedDataBanner: true,
    );
  }

  return NetworkErrorView(
    title: 'Something went wrong',
    message: fallbackMessage ?? (error is ApiException ? error.message : error.toString()),
    action: NetworkErrorAction.retry,
    showCachedDataBanner: false,
  );
}

/// Shows relogin / retry suggestions in a consistent way.
///
/// This function is intentionally small: screens decide their own retry
/// callback and their own widgets/banner placement.
void applyNetworkErrorAction({
  required BuildContext context,
  required NetworkErrorView view,
  VoidCallback? onRetry,
}) {
  if (view.action == NetworkErrorAction.relogin) {
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.onboarding, (r) => false);
    return;
  }

  if (view.action == NetworkErrorAction.retry) {
    onRetry?.call();
  }
}

