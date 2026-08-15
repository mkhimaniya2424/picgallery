/// Tiny in-memory flag store: "has this app session already seen the
/// onboarding carousel?"
///
/// Per the project brief this app must not use Hive, SharedPreferences,
/// or any other on-device persistence — so this intentionally does NOT
/// survive an app restart. It only survives within the current app
/// session (e.g. hot reload, or Splash -> Onboarding -> Home in one
/// run), which is enough for the "don't show onboarding twice in the
/// same session" behavior without touching disk.
///
/// Backend-agnostic by design: every caller talks to
/// [hasSeenOnboarding] / [markOnboardingSeen] only, so swapping this for
/// a real backend-backed flag later means editing just this file —
/// [SplashScreen] and [OnboardingScreen] never need to change.
class OnboardingLocalStore {
  static bool _hasSeenOnboarding = false;

  /// Returns `true` once the user has completed or skipped onboarding
  /// at least once during this app session. Always starts `false` on a
  /// fresh app launch, so onboarding shows on every cold start.
  Future<bool> hasSeenOnboarding() async => _hasSeenOnboarding;

  /// Marks onboarding as seen for the rest of this app session, so the
  /// next Splash visit (within the same run) skips straight to Role
  /// Selection. Called from both "Skip" and "Get Started".
  Future<void> markOnboardingSeen() async {
    _hasSeenOnboarding = true;
  }
}
