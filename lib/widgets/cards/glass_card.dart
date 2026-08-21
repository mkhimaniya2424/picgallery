import 'dart:ui';
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// A frosted, semi-transparent panel with a soft border and shadow — the
/// core glassmorphism building block used across Picgallery. Automatically
/// adapts fill and border colors to the current light/dark theme.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blurSigma;
  final Color? fillColor;
  final Border? border;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.borderRadius = AppRadius.lg,
    this.blurSigma = 18,
    this.fillColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultFill = isDark
        ? AppColors.darkSurfaceRaised.withValues(alpha: 0.72)
        : AppColors.glassFill;

    final defaultBorderColor = isDark
        ? AppColors.darkBorder
        : AppColors.glassBorder;

    final topFill = isDark
        ? Color.alphaBlend(
            AppColors.textOnDark.withValues(alpha: 0.04),
            fillColor ?? defaultFill)
        : Color.alphaBlend(
            Colors.white.withValues(alpha: 0.14),
            fillColor ?? defaultFill);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.30),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : AppShadows.soft(AppColors.primary, opacity: 0.10, blur: 32, y: 14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: border ?? Border.all(color: defaultBorderColor, width: 1),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [topFill, fillColor ?? defaultFill],
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
