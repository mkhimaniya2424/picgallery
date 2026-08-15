import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// Small inline "nothing here" card used inside scrollable sections
/// (dashboard sections, notification list, search results) — lighter
/// weight than [EmptyTabPlaceholder], which is reserved for full-tab
/// empty states.
class EmptyStateCard extends StatelessWidget {
  final String message;
  final IconData? icon;

  const EmptyStateCard({super.key, required this.message, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 30, color: AppColors.subtitle),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.subtitle),
          ),
        ],
      ),
    );
  }
}
