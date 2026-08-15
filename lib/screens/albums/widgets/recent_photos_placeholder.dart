import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

class RecentPhotosPlaceholder extends StatelessWidget {
  const RecentPhotosPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Photos',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.text),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _photoThumb(),
              const SizedBox(width: AppSpacing.sm),
              _photoThumb(),
              const SizedBox(width: AppSpacing.sm),
              _photoThumb(),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Photo timeline will appear here in later phases.',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.subtitle),
          ),
        ],
      ),
    );
  }

  Widget _photoThumb() {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.softWash,
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Icon(Icons.image_rounded,
                  color: AppColors.subtitle, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}
