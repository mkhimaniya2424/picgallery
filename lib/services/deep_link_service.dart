import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/routes/app_routes.dart';
import '../models/user.dart';
import '../providers/auth_providers.dart';
import '../widgets/common/snackbar_helper.dart';


/// Listens for the `picgallery://payment-success` / `picgallery://payment-failed`
/// links that the picgallery.in website redirects to once a Razorpay checkout
/// (started from [SubscriptionPlansScreen]) finishes, and for
/// `picgallery://email-verified`, which `verify_email_link` in the backend
/// (`app/api/routes/auth.py`) redirects to once the browser page it renders
/// has consumed the verification token — this is what lets a user land back
/// in the app automatically after tapping the link in their email, instead
/// of being stuck on that browser page with no way back in.
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
      case 'email-verified':
        _handleEmailVerified(navigatorKey);
        break;
      default:
        break;
    }
  }

  /// The token was already consumed server-side by `verify_email_link`
  /// before it redirected here, so there's nothing left to POST — this
  /// just needs to refresh the cached [AppUser] (whose `isEmailVerified`
  /// is otherwise stuck at the stale `false` from register/login) and
  /// then continue exactly where `login_screen.dart`'s `_navigateAfterAuth`
  /// would, minus the now-satisfied verified check.
  Future<void> _handleEmailVerified(GlobalKey<NavigatorState> navigatorKey) async {
    final context = navigatorKey.currentContext;
    final navigator = navigatorKey.currentState;
    if (context == null || navigator == null) return;

    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await container.read(authProvider.notifier).refreshMe();
    } catch (_) {
      return;
    }

    final user = container.read(authProvider).valueOrNull;
    if (user == null) return;

    final legacyRole = user.role == AppUserRole.photographer ? UserRole.photographer : UserRole.client;

    if (!user.hasCompletedProfile) {
      navigator.pushNamedAndRemoveUntil(
        AppRoutes.completeProfile,
        (route) => false,
        arguments: legacyRole,
      );
      return;
    }

    final destination = legacyRole == UserRole.photographer ? AppRoutes.adminHome : AppRoutes.home;
    navigator.pushNamedAndRemoveUntil(destination, (route) => false);
  }

}