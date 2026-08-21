import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Full-screen backdrop: soft lavender wash, no decorative shapes.
/// Adapts automatically to light/dark mode.
///
/// Light: soft lavender softWash gradient.
/// Dark:  deep darkBackground canvas.
///
/// Previously rendered three large blurred circular "orb" shapes behind
/// the content on every screen that uses this backdrop (splash, auth,
/// onboarding, client home, etc.) — removed per design request.
class ScreenBackdrop extends StatelessWidget {
  final Widget child;

  const ScreenBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark
        ? const BoxDecoration(color: AppColors.darkBackground)
        : const BoxDecoration(gradient: AppColors.softWash);

    return Container(
      decoration: bg,
      child: child,
    );
  }
}