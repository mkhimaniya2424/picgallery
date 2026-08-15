import '../core/network/api_client.dart';
import '../core/storage/token_storage.dart';
import '../models/user.dart';

/// Wires the `/auth/*` FastAPI endpoints (`app/api/routes/auth.py`) up to
/// [ApiClient], returning typed [AuthToken]/[AppUser] responses. Any
/// non-2xx response surfaces as an [ApiException] from [ApiClient] —
/// callers (providers/UI) are expected to catch it.
///
/// On a successful [register]/[socialLogin]/[login], the access token is
/// always stored in [ApiClient.authToken] (so subsequent authenticated
/// calls on this same client work immediately). Whether it's *also*
/// persisted via [TokenStorage] — so it survives app restarts — depends on
/// [login]'s `rememberMe` flag; see [_persistToken]. [logout] does the
/// reverse (clears both the in-memory token and anything persisted).
class AuthRepository {
  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  AuthRepository({
    required ApiClient apiClient,
    TokenStorage? tokenStorage,
  })  : _apiClient = apiClient,
        _tokenStorage = tokenStorage ?? TokenStorage();

  /// [rememberMe] controls whether [token] survives a cold app restart:
  ///
  /// - `true` (the default — used by [register]/[socialLogin], which have
  ///   no "remember me" checkbox of their own): the token is written to
  ///   [ApiClient] *and* persisted via [TokenStorage], same as before.
  /// - `false` (only ever passed by [login] when the user unchecked
  ///   "Remember me"): the token is only kept in memory on [ApiClient] for
  ///   the rest of this process's lifetime — nothing is written to disk,
  ///   and any token persisted by a *previous*, remembered session is
  ///   actively cleared so it doesn't linger and auto-login next launch.
  Future<void> _persistToken(String token, {bool rememberMe = true}) async {
    _apiClient.authToken = token;
    await _tokenStorage.saveRememberMe(rememberMe);
    if (rememberMe) {
      await _tokenStorage.saveToken(token);
    } else {
      await _tokenStorage.clearToken();
    }
  }

  /// Restores a previously-persisted token (e.g. on app startup) into
  /// the [ApiClient] so authenticated calls work without a fresh login.
  /// Returns the token if one was found, otherwise null.
  ///
  /// Nothing here needs to consult the "remember me" flag: if it was
  /// `false`, [_persistToken] never wrote a token to storage in the first
  /// place, so [TokenStorage.readToken] naturally returns null and the
  /// app starts logged out, exactly as if this method didn't exist.
  Future<String?> restoreSession() async {
    final token = await _tokenStorage.readToken();
    if (token != null) {
      _apiClient.authToken = token;
    }
    return token;
  }

  /// POST /auth/register — the 3-step registration form. [studioName],
  /// [studioAddress] and [businessType] only matter (and are required by
  /// the backend) when [role] is [AppUserRole.photographer].
  Future<AuthToken> register({
    required String fullName,
    required String email,
    required String password,
    required AppUserRole role,
    required bool agreedToTerms,
    String? studioName,
    String? studioAddress,
    String? businessType,
  }) async {
    final json = await _apiClient.post(
      '/auth/register',
      withAuth: false,
      body: {
        'full_name': fullName,
        'email': email,
        'password': password,
        'role': role.toJson(),
        'studio_name': studioName,
        'studio_address': studioAddress,
        'business_type': businessType,
        'agreed_to_terms': agreedToTerms,
      },
    );
    final token = AuthToken.fromJson(json as Map<String, dynamic>);
    await _persistToken(token.accessToken);
    return token;
  }

  /// POST /auth/login. [role], if known (e.g. picked on Role Selection
  /// just before this screen), disambiguates when the same email is
  /// registered under both a client and a photographer account —
  /// otherwise the backend has no way to know which one's password to
  /// check and returns a 400 asking the app to specify one.
  ///
  /// [rememberMe] mirrors the "Remember me" checkbox on [LoginScreen]:
  /// when `false`, the resulting token is kept in memory only (see
  /// [_persistToken]) so a fully-killed-and-relaunched app comes back up
  /// logged out instead of auto-restoring this session.
  Future<AuthToken> login(
    String email,
    String password, {
    AppUserRole? role,
    bool rememberMe = true,
  }) async {
    final json = await _apiClient.post(
      '/auth/login',
      withAuth: false,
      body: {
        'email': email,
        'password': password,
        if (role != null) 'role': role.toJson(),
      },
    );
    final token = AuthToken.fromJson(json as Map<String, dynamic>);
    await _persistToken(token.accessToken, rememberMe: rememberMe);
    return token;
  }

  /// POST /auth/social-login — Sign in with Google / Sign in with Apple.
  /// [role] is required, same as [register] (not optional like [login]):
  /// there's no password to fall back on for disambiguation, so the app
  /// must always know which role it's signing in as before calling this
  /// — i.e. Role Selection must have already happened, exactly like the
  /// email flow. [fullName] is only meaningful on first sign-up (Apple
  /// only ever hands the name back on the very first authorization) and
  /// is ignored by the backend on subsequent calls.
  Future<AuthToken> socialLogin({
    required String provider,
    required String idToken,
    required AppUserRole role,
    String? fullName,
  }) async {
    final json = await _apiClient.post(
      '/auth/social-login',
      withAuth: false,
      body: {
        'provider': provider,
        'id_token': idToken,
        'role': role.toJson(),
        if (fullName != null) 'full_name': fullName,
      },
    );
    final token = AuthToken.fromJson(json as Map<String, dynamic>);
    await _persistToken(token.accessToken);
    return token;
  }

  /// GET /auth/me
  Future<AppUser> getMe() async {
    final json = await _apiClient.get('/auth/me');
    return AppUser.fromJson(json as Map<String, dynamic>);
  }

  /// PUT /auth/complete-profile — final onboarding step. [studioName]
  /// and [specializations] are only applied by the backend when the
  /// authenticated user's role is photographer.
  Future<AppUser> completeProfile({
    required String fullName,
    String? phone,
    String? country,
    String? state,
    String? city,
    String? address,
    String? bio,
    String? studioName,
    List<String>? specializations,
  }) async {
    final json = await _apiClient.put(
      '/auth/complete-profile',
      body: {
        'full_name': fullName,
        'phone': phone,
        'country': country,
        'state': state,
        'city': city,
        'address': address,
        'bio': bio,
        'studio_name': studioName,
        'specializations': specializations,
      },
    );
    return AppUser.fromJson(json as Map<String, dynamic>);
  }

  /// POST /auth/send-verification-email — backs the "Resend Email"
  /// button. Returns the backend's confirmation message.
  Future<String> sendVerificationEmail() async {
    final json = await _apiClient.post('/auth/send-verification-email');
    return (json as Map<String, dynamic>)['message'] as String;
  }

  /// POST /auth/verify-email — consumes the (dummy) verification token.
  /// Not authenticated: the token itself is the credential.
  Future<AppUser> verifyEmail(String token) async {
    final json = await _apiClient.post(
      '/auth/verify-email',
      withAuth: false,
      body: {'token': token},
    );
    return AppUser.fromJson(json as Map<String, dynamic>);
  }

  /// PUT /auth/permissions — items 15-17 (Camera / Photo Library / Push
  /// Notification prompts). Only non-null fields are sent, so each
  /// screen can send just the one flag it owns.
  Future<AppUser> updatePermissions({
    bool? cameraPermissionGranted,
    bool? photoLibraryPermissionGranted,
    bool? pushNotificationsEnabled,
  }) async {
    final body = <String, dynamic>{};
    if (cameraPermissionGranted != null) {
      body['camera_permission_granted'] = cameraPermissionGranted;
    }
    if (photoLibraryPermissionGranted != null) {
      body['photo_library_permission_granted'] = photoLibraryPermissionGranted;
    }
    if (pushNotificationsEnabled != null) {
      body['push_notifications_enabled'] = pushNotificationsEnabled;
    }

    final json = await _apiClient.put('/auth/permissions', body: body);
    return AppUser.fromJson(json as Map<String, dynamic>);
  }

  /// POST /auth/forgot-password — backs [ForgotPasswordScreen]'s Send
  /// Reset Link button and [CheckEmailScreen]'s Resend link. Not
  /// authenticated (the user isn't logged in at this point) and always
  /// returns 200 with a generic message regardless of whether the email
  /// is registered, so there's nothing to branch on here beyond a
  /// network/ApiException failure.
  Future<String> forgotPassword(String email) async {
    final json = await _apiClient.post(
      '/auth/forgot-password',
      withAuth: false,
      body: {'email': email},
    );
    return (json as Map<String, dynamic>)['message'] as String;
  }

  /// POST /auth/reset-password — consumes the (dummy) reset-password
  /// token and sets a new password. Not authenticated: the token itself
  /// is the credential.
  Future<String> resetPassword({required String token, required String newPassword}) async {
    final json = await _apiClient.post(
      '/auth/reset-password',
      withAuth: false,
      body: {'token': token, 'new_password': newPassword},
    );
    return (json as Map<String, dynamic>)['message'] as String;
  }

  /// Clears the token from both the in-memory [ApiClient] and secure
  /// storage. Purely local — there's no backend logout endpoint (JWTs
  /// are stateless), so this is all that's needed to log the user out.
  Future<void> logout() async {
    _apiClient.authToken = null;
    await _tokenStorage.clearToken();
    await _tokenStorage.clearRememberMe();
  }
}
