import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// Storage Usage summary card — shows how much storage the studio has
/// used. Every PicGallery plan (`SubscriptionPlanModel.plans`) advertises
/// "Unlimited Storage" and the backend's `/admin-dashboard/stats` never
/// returns a quota/limit field, so there is no real denominator to turn
/// this into a percentage. [percentUsed] is therefore nullable: pass a
/// real 0.0–1.0 value only if a genuine quota exists somewhere, and
/// leave it null (the normal case today) to show an honest "Unlimited"
/// state instead of a fabricated fill amount.
class StorageUsageCard extends StatelessWidget {
  final String usedLabel;
  final String totalLabel;
  final double? percentUsed;
  final VoidCallback? onTap;

  const StorageUsageCard({
    super.key,
    required this.usedLabel,
    required this.totalLabel,
    this.percentUsed,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = percentUsed?.clamp(0.0, 1.0);
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
                if (clamped == null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: const Text('Unlimited',
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary)),
                  )
                else
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: isDark ? AppColors.subtitleOnDark : AppColors.subtitle),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (clamped != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: clamped,
                  minHeight: 10,
                  backgroundColor: isDark ? AppColors.darkBorder : AppColors.border,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                ),
              )
            else
              // No real quota to fill a bar against — a solid brand-color
              // bar communicates "plenty of room" without implying a
              // percentage-of-cap number that doesn't exist.
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                  ),
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
                if (clamped != null && totalLabel.trim().isNotEmpty)
                  Text('of $totalLabel',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.subtitleOnDark : AppColors.subtitle))
                else if (clamped == null)
                  Text('no storage limit',
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