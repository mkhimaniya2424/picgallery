import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Thrown when the user backs out of the native Google/Apple sheet
/// (as opposed to any real failure) — callers should treat this as a
/// silent no-op rather than showing an error popup.
class SocialAuthCancelled implements Exception {}

/// Provider-agnostic result of a successful on-device sign-in, ready to
/// hand to `AuthRepository.socialLogin`. [idToken] is what the backend
/// actually verifies (`core/social_auth.py`) — everything else here is
/// just first-sign-up convenience data.
class SocialAuthResult {
  final String provider; // 'google' | 'apple' — matches AuthProvider.toJson()
  final String idToken;
  final String? fullName;

  const SocialAuthResult({required this.provider, required this.idToken, this.fullName});
}

/// Thin wrapper around the `google_sign_in` and `sign_in_with_apple`
/// plugins. Kept separate from [AuthRepository] so the repository only
/// ever deals with our own backend's HTTP shape, not two unrelated
/// native SDKs.
class SocialAuthService {
  bool _googleInitialized = false;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    // serverClientId is REQUIRED on Android for google_sign_in to populate
    // the idToken. Must be the Web OAuth client ID (type 3) from
    // google-services.json — NOT the Android client ID. The backend
    // verifies this token's `aud` claim against GOOGLE_CLIENT_IDS in .env.
    await GoogleSignIn.instance.initialize(
      serverClientId: '198690480208-ubgq186vdo50uf336g6pp9t6213tdndf.apps.googleusercontent.com',
    );
    _googleInitialized = true;
  }

  /// Opens the native Google account picker. Throws [SocialAuthCancelled]
  /// if the user dismisses it, or a plain [Exception] if Google signed
  /// them in but (unusually) didn't hand back an ID token.
  Future<SocialAuthResult> signInWithGoogle() async {
    await _ensureGoogleInitialized();

    // Without this, the plugin silently re-uses whichever Google
    // account was picked last time (no account picker shown at all)
    // any time a cached session still exists — e.g. signing up for a
    // second (dual client + photographer) account with a different
    // Google account, or simply wanting to switch accounts, without
    // having logged out first. Forcing a sign-out first guarantees
    // the native picker always appears.
    await GoogleSignIn.instance.signOut();

    try {
      final GoogleSignInAccount account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile'],
      );

      final GoogleSignInAuthentication auth = account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        throw Exception("Google didn't return a sign-in token. Please try again.");
      }

      return SocialAuthResult(provider: 'google', idToken: idToken, fullName: account.displayName);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled || e.code == GoogleSignInExceptionCode.interrupted) {
        throw SocialAuthCancelled();
      }
      rethrow;
    }
  }

  /// Opens the native "Sign in with Apple" sheet. Throws
  /// [SocialAuthCancelled] if the user dismisses it.
  ///
  /// Apple only ever includes the user's name on the very first
  /// authorization for this app — every later sign-in returns
  /// `givenName`/`familyName` as null, which is expected, not an error;
  /// the backend already has the name saved from that first call.
  Future<SocialAuthResult> signInWithApple() async {
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) throw SocialAuthCancelled();
      rethrow;
    }

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw Exception("Apple didn't return a sign-in token. Please try again.");
    }

    final fullName = [credential.givenName, credential.familyName]
        .where((s) => s != null && s.trim().isNotEmpty)
        .join(' ')
        .trim();

    return SocialAuthResult(
      provider: 'apple',
      idToken: idToken,
      fullName: fullName.isEmpty ? null : fullName,
    );
  }

  /// Clears the cached Google session so the account picker is shown
  /// again next time (rather than silently re-using the last account).
  /// Call this alongside [AuthRepository.logout].
  Future<void> signOutGoogle() async {
    if (!_googleInitialized) return;
    await GoogleSignIn.instance.signOut();
  }
}
