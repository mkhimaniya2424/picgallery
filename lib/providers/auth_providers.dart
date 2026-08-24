import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/storage/token_storage.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';
import '../services/push_notification_service.dart';
import '../services/social_auth_service.dart';

/// Swap this single line to change how the app talks to the backend
/// (different base URL, mock client for tests, etc.) — nothing else
/// needs to change since everything below only depends on [ApiClient].
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(client.dispose);
  return client;
});

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

/// Wraps the native Google/Apple sign-in SDKs — see [SocialAuthService].
/// A single instance is shared so [GoogleSignIn]'s own cached session
/// state (silent sign-in, sign-out) behaves consistently app-wide.
final socialAuthServiceProvider = Provider<SocialAuthService>((ref) => SocialAuthService());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiClient: ref.watch(apiClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

/// Lightweight, synchronous view of auth state for widgets that would
/// rather not pattern-match on [AsyncValue] directly. Derived from
/// [authProvider] — [authProvider] (an [AsyncNotifier]) remains the
/// single source of truth, matching the house style already used by
/// [AdminDashboardNotifier].
class AuthState {
  final AppUser? user;
  final bool isLoading;

  const AuthState({this.user, this.isLoading = false});

  bool get isLoggedIn => user != null;
}

final authStateProvider = Provider<AuthState>((ref) {
  final async = ref.watch(authProvider);
  return AuthState(
    user: async.valueOrNull,
    isLoading: async.isLoading,
  );
});

/// Async, mutable auth state. `null` means "logged out" (no user, no
/// valid session); a non-null [AppUser] means "logged in". Every screen
/// that needs the current user watches this provider directly, or reads
/// the simpler [authStateProvider] view above.
final authProvider = AsyncNotifierProvider<AuthNotifier, AppUser?>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<AppUser?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  /// On app start: if a token was persisted from a previous session,
  /// restore it into [ApiClient] and fetch the current user with it. If
  /// the token is missing, expired, or otherwise rejected, fall back to
  /// logged-out (`null`) rather than surfacing an error on launch.
  @override
  Future<AppUser?> build() async {
    final token = await _repo.restoreSession();
    if (token == null) return null;

    try {
      final user = await _repo.getMe();
      // Sync FCM token for returning users so their device is always up to date
      _syncFcmToken();
      return user;
    } on ApiException catch (e) {
      // Only a real auth rejection (expired/invalid token) should log the
      // user out and wipe the saved session. Anything else — no network
      // yet at cold start, a timeout, a 5xx — is a transient failure, not
      // proof the token is bad, so leave it on disk and just report
      // logged-out for *this* launch; the next successful launch will
      // restore the session normally.
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _repo.logout();
      }
      return null;
    }
  }

  /// Runs [action], updates [state] to loading then data/error around
  /// it — same as `AsyncValue.guard` — but also rethrows the original
  /// error. Screens (register/login/complete-profile/...) need the
  /// `catch (ApiException e)` in their own `_next()`/`_handleSignIn()`
  /// to actually fire (e.g. to show an inline banner with `e.message`),
  /// which plain `AsyncValue.guard` wouldn't allow since it swallows the
  /// exception into `AsyncError` instead of letting it propagate.
  Future<void> _mutate(Future<AppUser?> Function() action) async {
    state = const AsyncLoading<AppUser?>().copyWithPrevious(state);
    try {
      final result = await action();
      state = AsyncData<AppUser?>(result);
    } catch (e, st) {
      state = AsyncError<AppUser?>(e, st);
      rethrow;
    }
  }

  /// POST /auth/register. [studioName]/[studioAddress]/[businessType]
  /// only matter when [role] is [AppUserRole.photographer].
  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    required AppUserRole role,
    required bool agreedToTerms,
    String? studioName,
    String? studioAddress,
    String? businessType,
  }) async {
    await _mutate(() async {
      final token = await _repo.register(
        fullName: fullName,
        email: email,
        password: password,
        role: role,
        agreedToTerms: agreedToTerms,
        studioName: studioName,
        studioAddress: studioAddress,
        businessType: businessType,
      );
      // Sync FCM token now that we have a valid session
      _syncFcmToken();
      return token.user;
    });
  }

  /// Grabs the current FCM token from Firebase and syncs it to the backend.
  /// Must be called after a valid auth token exists in [ApiClient].
  void _syncFcmToken() {
    final apiClient = ref.read(apiClientProvider);
    PushNotificationService.instance.syncFcmToken(apiClient);
  }

  /// POST /auth/login. [role] disambiguates when this email is
  /// registered under both a client and photographer account. [rememberMe]
  /// (from the Login screen's checkbox) is forwarded as-is to
  /// [AuthRepository.login] — see that method for what it actually does.
  Future<void> login(
    String email,
    String password, {
    AppUserRole? role,
    bool rememberMe = true,
  }) async {
    await _mutate(() async {
      final token = await _repo.login(email, password, role: role, rememberMe: rememberMe);
      // Sync FCM token now that we have a valid session
      _syncFcmToken();
      return token.user;
    });
  }

  /// POST /auth/social-login. [role] is required — same reasoning as
  /// [AuthRepository.socialLogin]: Role Selection must already have
  /// happened, since there's no password to disambiguate with later.
  Future<void> socialLogin({
    required String provider,
    required String idToken,
    required AppUserRole role,
    String? fullName,
  }) async {
    await _mutate(() async {
      final token = await _repo.socialLogin(provider: provider, idToken: idToken, role: role, fullName: fullName);
      // Sync FCM token now that we have a valid session
      _syncFcmToken();
      return token.user;
    });
  }

  /// Clears the persisted token and resets state to logged-out. Local
  /// only — there's no backend logout endpoint since JWTs are stateless.
  /// Also clears the cached Google session so a later Google sign-in
  /// shows the account picker again instead of silently re-using
  /// whichever account was last used.
  Future<void> logout() async {
    await _repo.logout();
    try {
      await ref.read(socialAuthServiceProvider).signOutGoogle();
    } catch (_) {
      // Best-effort only — e.g. no Google Play Services on this device,
      // or the user never signed in with Google in the first place.
      // Local token/state clearing above is what actually matters.
    }
    state = const AsyncData<AppUser?>(null);
  }

  /// GET /auth/me — re-fetches the current user (e.g. pull-to-refresh
  /// on a profile screen, or after some other part of the app changes
  /// the user server-side).
  Future<void> refreshMe() async {
    await _mutate(_repo.getMe);
  }

  /// Calls POST /users/me/plan to activate a plan and updates the state.
  Future<void> activatePlan(String plan) async {
    await _mutate(() async {
      final apiClient = ref.read(apiClientProvider);
      final json = await apiClient.post('/users/me/plan', body: {'plan': plan});
      return AppUser.fromJson(json as Map<String, dynamic>);
    });
  }

  /// Applies an already-fetched [AppUser] straight into state — used by
  /// [EditProfileScreen] (Task 7) after a successful PATCH /users/me, so
  /// the rest of the app (profile screen greeting, etc.) reflects the
  /// change immediately. Deliberately not routed through [_repo]/`/auth`
  /// at all: `/users/me` is a separate backend router
  /// (`UserRepository`/`app/api/routes/users.py`), and this keeps
  /// [AuthNotifier] from having to depend on it just to update its own
  /// cached value.
  void setUser(AppUser user) {
    state = AsyncData<AppUser?>(user);
  }

  /// PUT /auth/complete-profile — final onboarding step.
  Future<void> completeProfile({
    required String fullName,
    String? country,
    String? state,
    String? city,
    String? address,
    String? bio,
    String? studioName,
    List<String>? specializations,
  }) async {
    await _mutate(() {
      return _repo.completeProfile(
        fullName: fullName,
        country: country,
        state: state,
        city: city,
        address: address,
        bio: bio,
        studioName: studioName,
        specializations: specializations,
      );
    });
  }

  /// PUT /auth/permissions — items 15-17 (Camera / Photo Library / Push
  /// Notification prompts). Only non-null fields are sent.
  Future<void> updatePermissions({
    bool? cameraPermissionGranted,
    bool? photoLibraryPermissionGranted,
    bool? pushNotificationsEnabled,
  }) async {
    await _mutate(() {
      return _repo.updatePermissions(
        cameraPermissionGranted: cameraPermissionGranted,
        photoLibraryPermissionGranted: photoLibraryPermissionGranted,
        pushNotificationsEnabled: pushNotificationsEnabled,
      );
    });
  }
}