import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// Storage Usage summary card — a gradient progress bar showing how
/// much of the studio's plan is used, driven off the "Storage Used"
/// [StatCardData] the dashboard already derives (so it never drifts out
/// of sync with the real stat tile).
class StorageUsageCard extends StatelessWidget {
  final String usedLabel;
  final String totalLabel;
  final double percentUsed;
  final VoidCallback? onTap;

  const StorageUsageCard({
    super.key,
    required this.usedLabel,
    required this.totalLabel,
    required this.percentUsed,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = percentUsed.clamp(0.0, 1.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceRaised : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
          boxShadow: AppShadows.soft(AppColors.primary,
              opacity: 0.08, blur: 24, y: 12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 6))
                    ],
                  ),
                  child: const Icon(Icons.storage_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text('Storage Usage',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.textOnDark : AppColors.text)),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: isDark ? AppColors.subtitleOnDark : AppColors.subtitle),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: clamped,
                minHeight: 10,
                backgroundColor: isDark ? AppColors.darkBorder : AppColors.border,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$usedLabel used',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textOnDark : AppColors.text)),
                if (totalLabel.trim().isNotEmpty)
                  Text('of $totalLabel',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.subtitleOnDark : AppColors.subtitle)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}