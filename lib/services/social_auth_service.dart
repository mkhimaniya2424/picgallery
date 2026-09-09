// Minimal platform-agnostic Google / Apple social auth service used by providers/screens.
// Implements the small surface the app expects from SocialAuthService in
// lib/providers/auth_providers.dart (signInWithGoogle, signOutGoogle, signInWithApple)
// and the SocialAuthResult/SocialAuthCancelled types used by callers.

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart' as gsign;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Result returned by SocialAuthService.signInWithGoogle / signInWithApple
/// — callers expect `.provider`, `.idToken` and `.fullName`.
class SocialAuthResult {
  final String provider;
  final String idToken;
  final String? fullName;

  SocialAuthResult({required this.provider, required this.idToken, this.fullName});
}

/// Thrown when the user cancels a social sign-in flow.
class SocialAuthCancelled implements Exception {}

/// Thrown when Google reports [16] Account reauth failed.
class SocialAuthReauthNeeded implements Exception {
  final String message;
  SocialAuthReauthNeeded(this.message);
  @override
  String toString() => 'SocialAuthReauthNeeded: $message';
}

/// Very small Google / Apple Sign-In helper used by UI code.
class SocialAuthService {
  SocialAuthService._private();
  factory SocialAuthService() => SocialAuthService._private();

  // IMPORTANT: the server client ID below must match the Web OAuth client
  // ID created in the Google Cloud Console / Firebase project.
  static const _webClientId =
      '198690480208-tbcuoe1ub5c40k3chro4pu9hemstd28h.apps.googleusercontent.com';

  /// Signs in with Google and returns an [SocialAuthResult] containing an
  /// ID token suitable for server-side verification. Throws
  /// [SocialAuthCancelled] when the user cancels the flow.
  Future<SocialAuthResult> signInWithGoogle() async {
    final gsign.GoogleSignIn gsInstance = gsign.GoogleSignIn(
      serverClientId: _webClientId,
      scopes: ['email', 'profile'],
    );

    gsign.GoogleSignInAccount? account;
    try {
      account = await gsInstance.signIn();
    } on PlatformException catch (e) {
      debugPrint('[SocialAuth] signInWithGoogle threw PlatformException: ${e.code} — ${e.message}');
      
      final String errStr = e.message ?? e.toString();
      if (errStr.contains('reauth') || errStr.contains('[16]')) {
        debugPrint('[SocialAuth] Detected reauth error — clearing stale tokens...');
        try {
          await gsInstance.disconnect();
        } catch (_) {
          try { await gsInstance.signOut(); } catch (_) {}
        }
        throw SocialAuthReauthNeeded(errStr);
      }
      
      if (e.code == 'sign_in_canceled') {
        throw SocialAuthCancelled();
      }
      rethrow;
    } catch (e) {
      debugPrint('[SocialAuth] signInWithGoogle threw: ${e.runtimeType} — $e');
      if (e.toString().toLowerCase().contains('cancel')) {
        throw SocialAuthCancelled();
      }
      rethrow;
    }

    if (account == null) {
      // In v6, a null return from signIn() means the user canceled the flow.
      throw SocialAuthCancelled();
    }

    final String? fullName = account.displayName;
    final gsign.GoogleSignInAuthentication auth = await account.authentication;
    final String? idToken = auth.idToken;

    if (idToken == null || idToken.isEmpty) {
      throw Exception('Google Sign-In returned no ID token');
    }

    return SocialAuthResult(provider: 'google', idToken: idToken, fullName: fullName);
  }

  // ── Debug: last error from signInWithGoogleSilent (cleared on each call) ──
  // Read this in the UI to surface the real exception without USB/adb.
  String? lastSilentError;

  Future<SocialAuthResult?> signInWithGoogleSilent() async {
    lastSilentError = null; // reset each attempt
    try {
      final gsign.GoogleSignIn gsInstance = gsign.GoogleSignIn(
        serverClientId: _webClientId,
        scopes: ['email', 'profile'],
      );

      final gsign.GoogleSignInAccount? account = await gsInstance.signInSilently();
      debugPrint('[SocialAuth] signInWithGoogleSilent result: ${account?.email ?? "null (no cached account)"}');

      if (account == null) return null;

      final gsign.GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;

      if (idToken == null || idToken.isEmpty) {
        debugPrint('[SocialAuth] signInWithGoogleSilent: silent account found but no idToken');
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
      debugPrint('[SocialAuth] signInWithGoogleSilent THREW:\n  type : ${e.runtimeType}\n  error: $e\n  stack: $stack');
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
      return SocialAuthResult(provider: 'apple', idToken: idToken, fullName: fullName.isEmpty ? null : fullName);
    } catch (e) {
      if (e.toString().toLowerCase().contains('cancel')) throw SocialAuthCancelled();
      rethrow;
    }
  }

  /// Best-effort sign out/cleanup for Google sign-in.
  Future<void> signOutGoogle() async {
    try {
      final gsign.GoogleSignIn gsInstance = gsign.GoogleSignIn(
        serverClientId: _webClientId,
      );
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
