import 'dart:ui';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Full-screen backdrop: soft lavender wash + two large, blurred gradient
/// orbs floating behind the content. Reused on Splash, Onboarding, Role
/// Selection, Login, Register, Forgot Password and Email Verification so
/// every auth screen shares the same luxury atmosphere without a boring
/// flat background.
class ScreenBackdrop extends StatelessWidget {
  final Widget child;

  const ScreenBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.softWash),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _blurOrb(220, AppColors.primary.withValues(alpha: 0.28)),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: _blurOrb(260, AppColors.accent.withValues(alpha: 0.22)),
          ),
          Positioned(
            top: 220,
            left: -60,
            child: _blurOrb(140, AppColors.secondary.withValues(alpha: 0.18)),
          ),
          // Positioned.fill forces the real content to take the exact
          // screen size (bounded width AND height) instead of the
          // loose/shrink-wrap constraints a plain Stack child gets.
          // Without this, on wide/short screens (foldables especially)
          // AuthContainer's height constraint could resolve to
          // effectively infinite, causing a real RenderFlex overflow
          // (the yellow/black hazard-stripe warning banner), and the
          // login card would only take its minimum intrinsic width
          // instead of centering across the available space.
          Positioned.fill(child: child),
        ],
      ),
    );
  }

  Widget _blurOrb(double size, Color color) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}