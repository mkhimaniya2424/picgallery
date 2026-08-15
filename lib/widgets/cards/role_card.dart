import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import 'glass_card.dart';

/// One of the two large role cards on [RoleSelectionScreen]. Animates a
/// gradient border + lift + scale when selected, so choosing a role feels
/// tactile and premium rather than a plain RadioListTile.
class RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> features;
  final bool selected;
  final VoidCallback onTap;

  const RoleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.features,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.02 : 1.0,
        duration: AppDurations.medium,
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: AppDurations.medium,
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, selected ? -4 : 0, 0),
          child: GlassCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            borderRadius: AppRadius.lg,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.glassBorder,
              width: selected ? 2 : 1.2,
            ),
            fillColor: selected
                ? Colors.white.withValues(alpha: 0.75)
                : AppColors.glassFill,
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 6),
                      ...features.map(
                        (f) => Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  size: 14, color: AppColors.success),
                              const SizedBox(width: 6),
                              Text(f,
                                  style:
                                      Theme.of(context).textTheme.bodyMedium),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: AppDurations.fast,
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: selected ? AppColors.buttonGradient : null,
                    border: Border.all(
                        color: selected ? Colors.transparent : AppColors.border,
                        width: 1.6),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded,
                          size: 16, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
