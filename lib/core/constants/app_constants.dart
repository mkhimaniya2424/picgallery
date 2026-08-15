/// Centralized spacing scale used across picgallery so every screen shares
/// the same premium, generous rhythm instead of magic numbers.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
}

/// Corner radii. 24px is the signature picgallery rounding per the brief.
class AppRadius {
  AppRadius._();

  static const double sm = 14;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 32;
  static const double pill = 100;
}

/// Shared animation durations/curves for fades, slides and hero transitions.
class AppDurations {
  AppDurations._();

  static const Duration fast = Duration(milliseconds: 220);
  static const Duration medium = Duration(milliseconds: 450);
  static const Duration slow = Duration(milliseconds: 800);
  static const Duration splash = Duration(seconds: 3);
}

class AppStrings {
  AppStrings._();

  static const String appName = 'picgallery';
  static const String tagline = 'Store • Manage • Share Memories';

  /// Shown in the Studio Drawer footer. Swap for `package_info_plus`'s
  /// `PackageInfo.fromPlatform()` once that dependency is added to the
  /// project, so this always matches the shipped build number.
  static const String appVersion = 'v1.0.0';
}
