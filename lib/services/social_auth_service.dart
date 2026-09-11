// Minimal platform-agnostic Google / Apple social auth service used by providers/screens.
// Implements the small surface the app expects from SocialAuthService in
// lib/providers/auth_providers.dart (signInWithGoogle, signOutGoogle, signInWithApple)
// and the SocialAuthResult/SocialAuthCancelled types used by callers.

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_sign_in/google_sign_in.dart' as gsign;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Result returned by SocialAuthService.signInWithGoogle / signInWithApple
/// — callers expect `.provider`, `.idToken` and `.fullName`.
class SocialAuthResult {
  final String provider;
  final String idToken;
  final String? fullName;

  SocialAuthResult(
      {required this.provider, required this.idToken, this.fullName});
}

/// Thrown when the user cancels a social sign-in flow.
class SocialAuthCancelled implements Exception {}

/// Thrown when Google reports [16] Account reauth failed.
/// The caller should clear any cached Google session and retry
/// [signInWithGoogle] — this forces a fresh Credential Manager flow.
class SocialAuthReauthNeeded implements Exception {
  final String message;
  SocialAuthReauthNeeded(this.message);
  @override
  String toString() => 'SocialAuthReauthNeeded: $message';
}

/// Very small Google / Apple Sign-In helper used by UI code. Uses
/// dynamic calls for GoogleSignIn so it works with both the older
/// and the newer credential-manager-based google_sign_in implementations
/// without causing analyzer errors about missing constructors/methods.
class SocialAuthService {
  SocialAuthService._private();
  factory SocialAuthService() => SocialAuthService._private();

  // IMPORTANT: the server client ID below must match the Web OAuth client
  // ID created in the Google Cloud Console / Firebase project. This exact
  // string is required by the backend to validate ID tokens minted for
  // the web client. Do NOT change unless you know the backend is expecting
  // a different OAuth client.
  static const _webClientId =
      '198690480208-tbcuoe1ub5c40k3chro4pu9hemstd28h.apps.googleusercontent.com';

  /// Signs in with Google and returns an [SocialAuthResult] containing an
  /// ID token suitable for server-side verification. Throws
  /// [SocialAuthCancelled] when the user cancels the flow.
  Future<SocialAuthResult> signInWithGoogle() async {
    final gsign.GoogleSignIn gsInstance = gsign.GoogleSignIn.instance;
    await gsInstance.initialize(
      serverClientId: _webClientId,
    );

    gsign.GoogleSignInAccount account;
    try {
      account = await gsInstance.authenticate(
        scopeHint: <String>['email', 'profile'],
      );
    } catch (e) {
      debugPrint(
          '[SocialAuth] signInWithGoogle authenticate() threw: ${e.runtimeType} — $e');
      if (e is gsign.GoogleSignInException) {
        debugPrint('[SocialAuth] GoogleSignInException code: ${e.code}');

        // ── [16] Account reauth failed ───────────────────────────────────
        // Credential Manager has stale/expired tokens and can't silently
        // refresh them. Clear cached state so the next attempt forces a
        // fresh consent flow, then signal the caller to retry.
        // NOTE: the field is 'description', not 'message' (google_sign_in v7).
        // We also check toString() as a safe fallback since description is nullable.
        final String errStr = e.description ?? e.toString();
        if (errStr.contains('reauth') || errStr.contains('[16]')) {
          debugPrint(
              '[SocialAuth] Detected reauth error — clearing stale tokens...');
          try {
            await gsInstance.disconnect();
          } catch (_) {
            try {
              await gsInstance.signOut();
            } catch (_) {}
          }
          throw SocialAuthReauthNeeded(errStr);
        }

        if (e.code == gsign.GoogleSignInExceptionCode.canceled ||
            e.code == gsign.GoogleSignInExceptionCode.interrupted) {
          throw SocialAuthCancelled();
        }
      }
      if (e.toString().toLowerCase().contains('cancel') ||
          e.toString().toLowerCase().contains('user cancelled')) {
        throw SocialAuthCancelled();
      }
      rethrow;
    }

    final String? fullName = account.displayName;
    final gsign.GoogleSignInAuthentication auth = account.authentication;
    final String? idToken = auth.idToken;

    if (idToken == null || idToken.isEmpty) {
      throw Exception('Google Sign-In returned no ID token');
    }

    return SocialAuthResult(
        provider: 'google', idToken: idToken, fullName: fullName);
  }

  /// Tries to silently recover the Google account the user already selected
  /// in a previous [signInWithGoogle] call — **no account picker UI shown**.
  ///
  /// Used on the Credential Manager false-cancel retry path
  /// (flutter/flutter#171761): after `authenticate()` fires a spurious
  /// "canceled" exception, the account is already cached; calling
  /// `authenticate()` again would show the picker a second time, which is
  /// confusing. This method uses [attemptLightweightAuthentication] — the
  /// v7 replacement for the removed `signInSilently()` — to fetch the
  /// cached account with zero UI.
  ///
  /// Returns `null` if no account is available silently (genuine cancel —
  /// caller should treat that as [SocialAuthCancelled]).
  // ── Debug: last error from signInWithGoogleSilent (cleared on each call) ──
  // Read this in the UI to surface the real exception without USB/adb.
  String? lastSilentError;

  Future<SocialAuthResult?> signInWithGoogleSilent() async {
    lastSilentError = null; // reset each attempt
    try {
      final gsign.GoogleSignIn gsInstance = gsign.GoogleSignIn.instance;
      await gsInstance.initialize(serverClientId: _webClientId);

      // attemptLightweightAuthentication() is the v7 no-UI equivalent of
      // the removed signInSilently(). It returns null if there is no
      // previously authenticated account to restore.
      final gsign.GoogleSignInAccount? account =
          await gsInstance.attemptLightweightAuthentication();
      debugPrint(
          '[SocialAuth] signInWithGoogleSilent result: ${account?.email ?? "null (no cached account)"}');

      if (account == null) return null;

      final gsign.GoogleSignInAuthentication auth = account.authentication;
      final String? idToken = auth.idToken;

      if (idToken == null || idToken.isEmpty) {
        debugPrint(
            '[SocialAuth] signInWithGoogleSilent: silent account found but no idToken');
        return null;
      }

      return SocialAuthResult(
        provider: 'google',
        idToken: idToken,
        fullName: account.displayName,
      );
    } catch (e, stack) {
      // ── DEBUG: surface the REAL error in the UI (remove after diagnosis) ──
      final errMsg = '[${e.runtimeType}] $e';
      lastSilentError = errMsg;
      debugPrint(
          '[SocialAuth] signInWithGoogleSilent THREW:\n  type : ${e.runtimeType}\n  error: $e\n  stack: $stack');
      return null; // treat any error as "not available silently"
    }
  }

  /// Signs in with Apple and returns an ID token + optional full name.

  /// Throws [SocialAuthCancelled] when the user cancels the flow.
  Future<SocialAuthResult> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) throw SocialAuthCancelled();

      final given = credential.givenName ?? '';
      final family = credential.familyName ?? '';
      final fullName = '$given $family'.trim();
      return SocialAuthResult(
          provider: 'apple',
          idToken: idToken,
          fullName: fullName.isEmpty ? null : fullName);
    } catch (e) {
      // The sign_in_with_apple package throws its own exceptions for
      // cancellation; map them to SocialAuthCancelled for callers.
      if (e.toString().toLowerCase().contains('cancel')) {
        throw SocialAuthCancelled();
      }
      rethrow;
    }
  }

  /// Best-effort sign out/cleanup for Google sign-in.
  Future<void> signOutGoogle() async {
    try {
      final gsign.GoogleSignIn gsInstance = gsign.GoogleSignIn.instance;
      try {
        await gsInstance.disconnect();
      } catch (_) {
        try {
          await gsInstance.signOut();
        } catch (_) {}
      }
    } catch (_) {
      // Silent fail — best effort only
    }
  }
}
