import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../models/settings_model.dart';
import '../../providers/settings_provider.dart';
import '../../storage/onboarding_local_store.dart';
import '../../widgets/common/screen_backdrop.dart';

/// Animated splash: logo scales/fades in over the gradient backdrop, the
/// tagline fades in after, then a soft loading dash before auto-navigating
/// onward.
///
/// Also owns the one-time, cold-start App Lock PIN gate: if
/// `settings.securityPinEnabled && settings.requirePinOnLaunch` are both
/// true, [AppRoutes.pinUnlock] is pushed first and only on a correct PIN
/// does navigation continue to Onboarding/Role Selection. This screen only
/// runs once per process start, so the PIN is never asked again mid-session.
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
      final destinationRoute =
          alreadySeenOnboarding ? AppRoutes.roleSelection : AppRoutes.onboarding;
      if (!mounted) return;

      // Read persisted settings directly from the store (bypassing the
      // provider's own async load) so this cold-start check is never
      // racing SettingsNotifier.build()'s background load — see
      // settings_provider.dart.
      final settingsData = await ref.read(settingsStoreProvider).load();
      final settings = settingsData != null
          ? SettingsModel.fromJson(settingsData)
          : const SettingsModel();
      if (!mounted) return;

      if (settings.securityPinEnabled && settings.requirePinOnLaunch) {
        Navigator.of(context).pushReplacementNamed(
          AppRoutes.pinUnlock,
          arguments: PinUnlockArgs(
            correctPin: settings.securityPin,
            destinationRoute: destinationRoute,
          ),
        );
        return;
      }

      Navigator.of(context).pushReplacementNamed(destinationRoute);
    });
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
