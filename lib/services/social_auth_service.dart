// Minimal platform-agnostic Google / Apple social auth service used by providers/screens.
// Implements the small surface the app expects from SocialAuthService in
// lib/providers/auth_providers.dart (signInWithGoogle, signOutGoogle) and
// the SocialAuthResult/SocialAuthCancelled types used by callers.

// Minimal platform-agnostic Google / Apple social auth service used by providers/screens.
// Implements the small surface the app expects from SocialAuthService in
// lib/providers/auth_providers.dart (signInWithGoogle, signOutGoogle, signInWithApple)
// and the SocialAuthResult/SocialAuthCancelled types used by callers.

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
    // Use the public API surface dynamically so this file doesn't fail
    // analysis on whichever flavor of google_sign_in the project uses.
    final dynamic gsInstance = gsign.GoogleSignIn.instance;

    String? idToken;
    String? fullName;

    // Try the newer `authenticate` method preferred by credential manager
    try {
      final dynamic authResult = await gsInstance.authenticate(
        serverClientId: _webClientId,
        scopes: <String>['email', 'profile'],
      );

      // authResult shapes vary by platform/version — try a few common accessors
      try {
        idToken = authResult.idToken as String?;
      } catch (_) {}
      try {
        idToken ??= authResult['idToken'] as String?;
      } catch (_) {}
      try {
        idToken ??= authResult.credential?.idToken as String?;
      } catch (_) {}

      // Some implementations return an account object alongside the auth
      try {
        fullName = authResult.displayName as String?;
      } catch (_) {}
      try {
        fullName ??= authResult.account?.displayName as String?;
      } catch (_) {}
    } catch (_) {
      // If `authenticate` isn't available or fails, fall back to traditional signIn()
      try {
        final dynamic account = await gsInstance.signIn(
          scopes: <String>['email', 'profile'],
          serverClientId: _webClientId,
        );
        if (account == null) throw SocialAuthCancelled();
        fullName = account.displayName as String?;
        final dynamic auth = await account.authentication;
        try {
          idToken = auth.idToken as String?;
        } catch (_) {}
        try {
          idToken ??= auth['idToken'] as String?;
        } catch (_) {}
      } catch (e) {
        // If the runtime doesn't expose signIn (NoSuchMethod), surface a
        // clearer error rather than letting the raw NoSuchMethodError bubble
        // up into the UI with an obscure stack trace.
        if (e is NoSuchMethodError) {
          throw Exception(
              'GoogleSignIn API mismatch at runtime: the GoogleSignIn instance does not expose signIn(). Ensure the installed google_sign_in package and platform implementation support either authenticate() or signIn(), or update SocialAuthService to match the runtime API.');
        }
        // If the user cancelled, reflect that with SocialAuthCancelled
        if (e is gsign.GoogleSignInAccount || e.toString().toLowerCase().contains('cancel') || e.toString().toLowerCase().contains('user cancelled')) {
          throw SocialAuthCancelled();
        }
        rethrow;
      }
    }

    if (idToken == null || idToken.isEmpty) {
      throw Exception('Google Sign-In returned no ID token');
    }

    return SocialAuthResult(provider: 'google', idToken: idToken, fullName: fullName);
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
      final fullName = (given + ' ' + family).trim();
      return SocialAuthResult(provider: 'apple', idToken: idToken, fullName: fullName.isEmpty ? null : fullName);
    } catch (e) {
      // The sign_in_with_apple package throws its own exceptions for
      // cancellation; map them to SocialAuthCancelled for callers.
      if (e.toString().toLowerCase().contains('cancel')) throw SocialAuthCancelled();
      rethrow;
    }
  }

  /// Best-effort sign out/cleanup for Google sign-in.
  Future<void> signOutGoogle() async {
    try {
      final dynamic gsInstance = gsign.GoogleSignIn.instance;
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
