import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Single source of truth for the PicsWalley palette: a soft-lavender
/// luxury SaaS look built around a purple → violet → pink gradient.
/// No blue is used anywhere, per the brief.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFFFAF8FF);
  static const Color primary = Color(0xFF7C5CFF);
  static const Color secondary = Color(0xFFA855F7);
  static const Color accent = Color(0xFFEC4899);
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color text = Color(0xFF111827);
  static const Color subtitle = Color(0xFF6B7280);
  static const Color border = Color(0xFFE9E5FF);
  static const Color surface = Colors.white;

  /// The signature three-stop hero gradient: primary → secondary → accent.
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary, accent],
  );

  /// Softer two-stop gradient for buttons and small accents.
  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primary, secondary],
  );

  /// Very light gradient wash used behind glass panels / blurred shapes.
  static const LinearGradient softWash = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF3EEFF), Color(0xFFFDF2F8)],
  );

  static Color glassFill = Colors.white.withValues(alpha: 0.55);
  static Color glassBorder = Colors.white.withValues(alpha: 0.6);

  /// Warm champagne-gold used sparingly for "premium" accents — badges,
  /// dividers, ring highlights. Never used as a primary fill.
  static const Color gold = Color(0xFFEFBF6B);

  /// Near-black ink used for the deep hero surfaces (replaces flat
  /// gradient-only heroes with a richer, editorial-dark panel option).
  static const Color ink = Color(0xFF1A1526);

  /// Slightly tinted white for stacked "elevated" surfaces above the
  /// base background, giving cards a sense of depth without a hard edge.
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  /// Hairline hero gradient used for 1px premium borders/dividers.
  static const LinearGradient hairlineGradient = LinearGradient(
    colors: [primary, secondary, accent],
  );

  // ---------------------------------------------------------------------
  // Dark-surface tokens — used by full-bleed "premium/elite" screens (e.g.
  // the Studio Dashboard) that adopt a deep editorial-dark canvas instead
  // of the light lavender background, while staying on-brand with the
  // same purple → violet → pink palette (no blue).
  // ---------------------------------------------------------------------

  /// Deepest canvas colour for dark premium screens.
  static const Color darkBackground = Color(0xFF0F0B1A);

  /// Elevated card surface sitting above [darkBackground].
  static const Color darkSurface = Color(0xFF221B38);

  /// Slightly higher-elevation surface (e.g. tiles nested inside a card).
  static const Color darkSurfaceRaised = Color(0xFF362A57);

  /// Hairline border colour for cards/tiles on dark surfaces.
  static const Color darkBorder = Color(0xFF675499);

  /// Primary (near-white) text colour on dark surfaces.
  static const Color textOnDark = Color(0xFFF5F3FF);

  /// Secondary / muted text colour on dark surfaces.
  static const Color subtitleOnDark = Color(0xFFA79FC2);
}

/// Shared layered box-shadow recipes so every "premium" surface reads
/// consistently: a soft, colored ambient glow plus a tight, true-black
/// contact shadow — rather than one flat, muddy shadow.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> soft(Color tint,
          {double opacity = 0.14, double blur = 28, double y = 14}) =>
      [
        BoxShadow(
            color: tint.withValues(alpha: opacity),
            blurRadius: blur,
            offset: Offset(0, y)),
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 6,
            offset: const Offset(0, 2)),
      ];

  static List<BoxShadow> raised(Color tint) =>
      soft(tint, opacity: 0.20, blur: 36, y: 20);

  static List<BoxShadow> subtle = [
    BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 16,
        offset: const Offset(0, 6)),
  ];
}

/// App-wide [ThemeData], built on Material 3 with the Poppins type scale
/// (Bold headings, Medium body, SemiBold buttons) requested in the brief.
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      tertiary: AppColors.accent,
      onTertiary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.darkSurface,
      onSurface: AppColors.textOnDark,
      surfaceContainerHighest: AppColors.darkSurfaceRaised,
      onSurfaceVariant: AppColors.subtitleOnDark,
      outline: AppColors.darkBorder,
      outlineVariant: AppColors.darkBorder,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: AppColors.textOnDark,
      onInverseSurface: AppColors.darkBackground,
      inversePrimary: AppColors.primary,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      fontFamily: GoogleFonts.poppins().fontFamily,
    );

    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.poppins(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: AppColors.textOnDark),
      headlineLarge: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.textOnDark),
      headlineMedium: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textOnDark),
      titleLarge: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textOnDark),
      bodyLarge: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.textOnDark),
      bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.subtitleOnDark),
      labelLarge: GoogleFonts.poppins(
          fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textOnDark),
        actionsIconTheme: const IconThemeData(color: AppColors.textOnDark),
        titleTextStyle: textTheme.titleLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceRaised,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        labelStyle:
            TextStyle(color: AppColors.subtitleOnDark, fontSize: 14),
        hintStyle:
            TextStyle(color: AppColors.subtitleOnDark.withValues(alpha: 0.6)),
        prefixIconColor: AppColors.primary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.error, width: 1.6),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        space: 1,
        thickness: 1,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return AppColors.subtitleOnDark;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.darkSurfaceRaised;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: AppColors.darkBorder, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurfaceRaised,
        selectedColor: AppColors.primary,
        disabledColor: AppColors.darkSurface,
        labelStyle: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textOnDark),
        secondaryLabelStyle: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
        side: const BorderSide(color: AppColors.darkBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        showCheckmark: false,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.primary,
        textColor: AppColors.textOnDark,
      ),
      iconTheme: const IconThemeData(color: AppColors.textOnDark),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkSurfaceRaised,
        contentTextStyle: GoogleFonts.poppins(
            color: AppColors.textOnDark, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AppColors.darkSurfaceRaised,
        surfaceTintColor: Colors.transparent,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.darkSurface,
        headerBackgroundColor: AppColors.darkBackground,
        headerForegroundColor: AppColors.textOnDark,
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return AppColors.textOnDark;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return Colors.transparent;
        }),
        todayForegroundColor: WidgetStateProperty.all(AppColors.primary),
        todayBorder: const BorderSide(color: AppColors.primary),
        weekdayStyle: const TextStyle(color: AppColors.subtitleOnDark),
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        tertiary: AppColors.accent,
        error: AppColors.error,
        surface: AppColors.surface,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: GoogleFonts.poppins().fontFamily,
    );

    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.poppins(
          fontSize: 34, fontWeight: FontWeight.w700, color: AppColors.text),
      headlineLarge: GoogleFonts.poppins(
          fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.text),
      headlineMedium: GoogleFonts.poppins(
          fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text),
      titleLarge: GoogleFonts.poppins(
          fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text),
      bodyLarge: GoogleFonts.poppins(
          fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.text),
      bodyMedium: GoogleFonts.poppins(
          fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.subtitle),
      labelLarge: GoogleFonts.poppins(
          fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.text),
        titleTextStyle: textTheme.titleLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.7),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }
}