import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../buttons/gradient_button.dart';
import 'screen_backdrop.dart';

/// Single reusable "please grant this permission" screen, driving all
/// three permission prompts (camera, photo library, push notifications)
/// off the same layout instead of three near-duplicate screens. Badge
/// styling (gradient circle + soft shadow) mirrors the success badge on
/// `email_verification_screen.dart` so the onboarding tail feels of a
/// piece with the rest of the auth flow.
///
/// Dummy only: neither [onAllow] nor [onSkip] talk to a real OS
/// permission API (no `permission_handler` dependency in this project) —
/// callers just decide where to navigate next, and per the brief "Not
/// Now" always advances the flow the same as "Allow Access" would.
class PermissionRequestSheet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onAllow;
  final VoidCallback onSkip;

  const PermissionRequestSheet({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onAllow,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ScreenBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 36, offset: const Offset(0, 16)),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 58),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(title, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.subtitle),
                ),
                const SizedBox(height: AppSpacing.xxl),
                GradientButton(label: 'Allow Access', onPressed: onAllow),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: onSkip,
                  child: const Text('Not Now', style: TextStyle(color: AppColors.subtitle, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
