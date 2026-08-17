import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user.dart';
import '../../providers/auth_providers.dart';
import '../../storage/onboarding_local_store.dart';
import '../../widgets/common/screen_backdrop.dart';

/// Animated splash: logo scales/fades in over the gradient backdrop, the
/// tagline fades in after, then a soft loading dash before auto-navigating.
///
/// Also doubles as the app's session bootstrap: while the animation plays,
/// [authProvider] resolves whatever [AuthRepository.restoreSession] found
/// (a persisted token from a previous "Remember me" login, or a Google/Apple
/// sign-in, which always persists). If that resolves to a logged-in
/// [AppUser], we skip straight past Role Selection/Login to that user's
/// home — same priority order [LoginScreen._navigateAfterAuth] uses, so a
/// still-valid session is only ever asked to log in again if
/// [AuthNotifier.build] itself found no valid token (missing, or rejected
/// as expired/invalid by GET /auth/me).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _taglineFade;

  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _logoScale = Tween(begin: 0.7, end: 1.0).animate(CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOutBack)));
    _logoFade = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.5, curve: Curves.easeOut)));
    _taglineFade = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut)));

    _controller.forward();

    _splashTimer = Timer(AppDurations.splash, () async {
      if (!mounted) return;
      // Backend-agnostic check: OnboardingLocalStore owns the only
      // persistence detail here (a Hive-backed flag today, but callers
      // never need to know that). Falls back to showing onboarding if
      // nothing has been persisted yet, or if the check fails.
      final alreadySeenOnboarding =
          await OnboardingLocalStore().hasSeenOnboarding();
      if (!mounted) return;

      if (!alreadySeenOnboarding) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.onboarding);
        return;
      }

      // Wait for AuthNotifier.build() to finish restoring whatever
      // AuthRepository.restoreSession() found (persisted token -> GET
      // /auth/me). authProvider.future resolves once that settles, whether
      // it lands on a logged-in AppUser or null (no token / rejected).
      AppUser? user;
      try {
        user = await ref.read(authProvider.future);
      } catch (_) {
        // AuthNotifier.build() already swallows expected failures (missing/
        // expired/rejected token) into a `null` result -- this only guards
        // against something unexpected (e.g. no network at all on launch).
        // Either way, fall back to a normal logged-out start rather than
        // getting the user stuck on the splash screen.
        user = null;
      }
      if (!mounted) return;

      if (user != null) {
        _navigateAfterAuth(user);
        return;
      }

      Navigator.of(context).pushReplacementNamed(AppRoutes.roleSelection);
    });
  }

  /// Same priority order as [LoginScreen._navigateAfterAuth]: unverified
  /// email first, then an incomplete profile, and only then role-based
  /// home. Kept in sync with that method deliberately -- see its doc
  /// comment.
  void _navigateAfterAuth(AppUser user) {
    final legacyRole =
        user.role == AppUserRole.photographer ? UserRole.photographer : UserRole.client;
    final navigator = Navigator.of(context);

    if (!user.isEmailVerified) {
      navigator.pushReplacementNamed(
        AppRoutes.verificationPending,
        arguments: {'email': user.email, 'role': legacyRole},
      );
      return;
    }

    if (!user.hasCompletedProfile) {
      navigator.pushReplacementNamed(AppRoutes.completeProfile, arguments: legacyRole);
      return;
    }

    final destination = legacyRole == UserRole.photographer ? AppRoutes.adminHome : AppRoutes.home;
    navigator.pushReplacementNamed(destination);
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _splashTimer = null;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ScreenBackdrop(
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Container(
                        width: 108,
                        height: 108,
                        decoration: BoxDecoration(
                          gradient: AppColors.heroGradient,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 40,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.camera_alt_rounded,
                            color: Colors.white, size: 52),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FadeTransition(
                    opacity: _logoFade,
                    child: ShaderMask(
                      shaderCallback: (b) =>
                          AppColors.heroGradient.createShader(b),
                      child: const Text(
                        AppStrings.appName,
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FadeTransition(
                    opacity: _taglineFade,
                    child: const Text(
                      AppStrings.tagline,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.subtitle,
                          letterSpacing: 0.3),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  FadeTransition(
                    opacity: _taglineFade,
                    child: SizedBox(
                      width: 120,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: const LinearProgressIndicator(
                          minHeight: 4,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}