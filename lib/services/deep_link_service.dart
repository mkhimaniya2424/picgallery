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
  GlobalKey<NavigatorState>? _navigatorKey;
  Uri? _pendingInitialUri;
  bool _isSplashActive = true;

  /// Returns whether a deep link is waiting to be processed
  /// after splash screen navigation completes.
  bool get hasPendingInitialLink => _pendingInitialUri != null;

  /// Call once from main.dart, after `runApp` — [navigatorKey] must be the
  /// same key passed to MaterialApp so we can navigate/show snackbars
  /// without needing a BuildContext from inside a widget.
  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;
    _isSplashActive = true;
    _pendingInitialUri = null;

    // App was fully closed and opened directly via the link (cold start).
    // Store as pending link so SplashScreen can process it on top of the
    // initial root route once startup initialization finishes.
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        debugPrint('[DEEP_LINK_DEBUG] Cold start initial deep link stored as pending: $initial');
        _pendingInitialUri = initial;
      }
    } catch (_) {
      // No initial link, or platform channel not ready yet — ignore.
    }

    // App was already running (backgrounded) or launched via link.
    // If splash is still active, defer handling until splash completes so
    // SplashScreen's pushReplacementNamed doesn't destroy the shared gallery route.
    _sub?.cancel();
    _sub = _appLinks.uriLinkStream.listen((uri) {
      debugPrint('[DEEP_LINK_DEBUG] uriLinkStream received: $uri (splashActive=$_isSplashActive)');
      if (_isSplashActive) {
        _pendingInitialUri = uri;
      } else {
        handleLink(uri);
      }
    });
  }

  /// Called by SplashScreen once root navigation completes. Executes the
  /// pending deep link on top of the root route so the shared gallery (or
  /// passcode gate) is presented immediately as the active screen, with the
  /// home/dashboard safely below it in the back stack.
  void onSplashComplete() {
    debugPrint('[DEEP_LINK_DEBUG] onSplashComplete called (pendingUri: $_pendingInitialUri)');
    _isSplashActive = false;
    final uri = _pendingInitialUri;
    _pendingInitialUri = null;
    if (uri != null) {
      debugPrint('[DEEP_LINK_DEBUG] Processing pending deep link after splash: $uri');
      handleLink(uri);
    }
  }

  void dispose() => _sub?.cancel();

  /// Resolves a `picgallery://` link into whatever screen/action it maps
  /// to. Every case that can fail to resolve (unrecognized host, a
  /// `studio`/`shared` link missing its id/token) now goes through
  /// [_reportFailure] instead of returning silently — this was
  /// previously a dead end for three separate callers: [ScanQrScreen]
  /// after a successful scan, a cold-start tap on a stale/broken share
  /// link from outside the app, and a backgrounded-app tap on the same.
  ///
  /// Also accepts `https://picgallery.in/...` App Links — same
  /// destinations, just a real https URL so chat apps like WhatsApp
  /// auto-linkify it (they never linkify a bare `picgallery://` URI).
  /// [_action] below normalizes both shapes to the same
  /// action-plus-remaining-segments form before dispatching.
  ///
  /// [onFailure], when provided, is called instead of the built-in
  /// snackbar — e.g. [ScanQrScreen] can use it to keep the camera
  /// running and let the person try another code rather than losing the
  /// scanner screen. When omitted (the [init]-driven cold-start/
  /// backgrounded-link paths, which have no screen-specific fallback of
  /// their own), a snackbar is shown directly on whatever screen is
  /// currently on top, the same way [_handlePaymentFailed] already
  /// does.
  void handleLink(Uri uri, {void Function(String message)? onFailure}) {
    debugPrint('[DEEP_LINK_DEBUG] Incoming deep link URI: $uri');
    final navKey = _navigatorKey;
    if (navKey == null) return;

    final parsed = _action(uri);
    debugPrint('[DEEP_LINK_DEBUG] Parsed action: ${parsed?.action}, id: ${parsed?.id}');
    if (parsed == null) return; // Not a picgallery link at all — ignore.

    switch (parsed.action) {
      case 'email-verified':
        _handleEmailVerified(navKey);
        break;
      case 'studio':
        _handleStudio(parsed.id, navKey, onFailure);
        break;
      case 'shared':
      case 'gallery':
        _handleShared(parsed.id, navKey, onFailure);
        break;
      case 'payment-success':
        _handlePaymentSuccess(uri, navKey);
        break;
      case 'payment-failed':
        _handlePaymentFailed(navKey);
        break;
      default:
        _reportFailure(navKey, onFailure, "That link isn't recognized by PicGallery.");
    }
  }

  /// Normalizes both supported link shapes into a single
  /// (action, id-or-token) pair:
  ///  - `picgallery://{action}/{id}`               (custom scheme)
  ///  - `https://api.picgallery.in/{action}/{id}`   (App Links)
  ///  - `https://picgallery.in/{action}/{id}`
  ///  - `https://picgallery.com/gallery/{id}`
  ///  - `https://www.picgallery.in/{action}/{id}`
  /// Returns null for anything else (a foreign scheme/host slipping
  /// through), so [handleLink] can bail out silently rather than
  /// showing an error for a link that was never ours.
  _ParsedAction? _action(Uri uri) {
    if (uri.scheme == 'picgallery') {
      final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      return _ParsedAction(uri.host, id);
    }
    if (uri.scheme == 'https' || uri.scheme == 'http') {
      final host = uri.host.toLowerCase();
      if (host == 'api.picgallery.in' ||
          host == 'picgallery.in' ||
          host == 'www.picgallery.in' ||
          host == 'picgallery.com' ||
          host == 'www.picgallery.com' ||
          host == 'picgallery.app' ||
          host == 'www.picgallery.app') {
        final segments = uri.pathSegments;
        if (segments.isEmpty) return null;
        final action = segments.first;
        final id = segments.length > 1 ? segments[1] : null;
        return _ParsedAction(action, id);
      }
    }
    return null;
  }

  /// Routes [onFailure] to the caller if given, otherwise falls back to
  /// a snackbar on whatever screen [navigatorKey] currently has on top
  /// — mirrors [_handlePaymentFailed]'s existing self-contained
  /// feedback rather than failing silently.
  void _reportFailure(
    GlobalKey<NavigatorState> navigatorKey,
    void Function(String message)? onFailure,
    String message,
  ) {
    if (onFailure != null) {
      onFailure(message);
      return;
    }
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      SnackBarHelper.showError(context, message);
    }
  }

  /// `picgallery://studio/{studioId}` or `https://api.picgallery.in/studio/{studioId}`
  /// — generated by the Dashboard's "Show My QR" quick action
  /// (`QuickActionHandler._showQrDialog`). [studioId] is a real
  /// `AppUser.id`, so this just opens the same `StudioProfileScreen`
  /// used everywhere else a studio is viewed — no separate "check-in"
  /// concept exists on the backend, so this is honestly just a shortcut
  /// to that profile, not a check-in.
  void _handleStudio(
    String? studioId,
    GlobalKey<NavigatorState> navigatorKey,
    void Function(String message)? onFailure,
  ) {
    if (studioId == null || studioId.isEmpty) {
      _reportFailure(navigatorKey, onFailure, "That studio code isn't valid.");
      return;
    }
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushNamed(AppRoutes.studioProfile, arguments: studioId);
  }

  /// `picgallery://shared/{token}` or `https://api.picgallery.in/shared/{token}`
  /// — generated by `ShareSettingsScreen`'s QR code and share sheet.
  /// [token] is the share link's opaque token (`ShareLinkRead.token`);
  /// opens `SharedGalleryScreen`, which resolves it against the real
  /// public `/public/share-links/{token}` API (no account/auth needed,
  /// same as a guest tapping the link directly).
  void _handleShared(
    String? token,
    GlobalKey<NavigatorState> navigatorKey,
    void Function(String message)? onFailure,
  ) {
    final cleanToken = token?.trim();
    debugPrint('[DEEP_LINK_DEBUG] Extracted shareId (token): $cleanToken');
    if (cleanToken == null || cleanToken.isEmpty) {
      _reportFailure(navigatorKey, onFailure, "That share link isn't valid.");
      return;
    }
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushNamed(AppRoutes.sharedGallery, arguments: cleanToken);
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

  Future<void> _handlePaymentSuccess(Uri uri, GlobalKey<NavigatorState> navigatorKey) async {
    final plan = uri.queryParameters['plan'];
    if (plan == null || plan.isEmpty) return;

    final context = navigatorKey.currentContext;
    final navigator = navigatorKey.currentState;
    if (context == null || navigator == null) return;

    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await container.read(authProvider.notifier).activatePlan(plan);
      navigator.pushNamed(AppRoutes.subscriptionPlans);
      if (context.mounted) {
        SnackBarHelper.showSuccess(context, 'Subscription upgraded successfully!');
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarHelper.showError(context, 'Failed to activate plan: $e');
      }
    }
  }

  void _handlePaymentFailed(GlobalKey<NavigatorState> navigatorKey) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    SnackBarHelper.showError(context, 'Payment failed. Please try again.');
  }
}

/// Normalized (action, id) pair produced by [DeepLinkService._action] —
/// e.g. ('shared', 'lTckOu4luVs') from either link shape it accepts.
class _ParsedAction {
  final String action;
  final String? id;
  const _ParsedAction(this.action, this.id);
}