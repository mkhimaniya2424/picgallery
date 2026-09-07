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
      if (e is gsign.GoogleSignInException) {
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
      final fullName = '$given $family'.trim();
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
