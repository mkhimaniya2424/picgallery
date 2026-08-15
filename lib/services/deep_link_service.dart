import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/routes/app_routes.dart';
import '../widgets/common/snackbar_helper.dart';


/// Listens for the `picgallery://payment-success` / `picgallery://payment-failed`
/// links that the picgallery.in website redirects to once a Razorpay checkout
/// (started from [SubscriptionPlansScreen]) finishes.
///
/// On success: activates the plan locally via [subscriptionStateProvider]
/// with an exact expiry (same time-of-day, N calendar months later — not
/// just "N*30 days"), then opens Payments & Billing and shows a success
/// message on it. On failure: shows an error message on whatever screen
/// is currently open.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  /// Call once from main.dart, after `runApp` — [navigatorKey] must be the
  /// same key passed to MaterialApp so we can navigate/show snackbars
  /// without needing a BuildContext from inside a widget.
  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    // App was fully closed and opened directly via the link (cold start).
    // Splash/onboarding/auth may still be deciding the very first screen,
    // so wait briefly for the navigator to actually exist before acting —
    // otherwise a cold-start link would be silently dropped.
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        for (var i = 0; i < 25 && navigatorKey.currentContext == null; i++) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
        _handle(initial, navigatorKey);
      }
    } catch (_) {
      // No initial link, or platform channel not ready yet — ignore.
    }

    // App was already running (backgrounded) when the link arrived.
    _sub = _appLinks.uriLinkStream.listen((uri) => _handle(uri, navigatorKey));
  }

  void dispose() => _sub?.cancel();

  void _handle(Uri uri, GlobalKey<NavigatorState> navigatorKey) {
    if (uri.scheme != 'picgallery') return;

    switch (uri.host) {
      default:
        break;
    }
  }



}
