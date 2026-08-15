import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin_dashboard_data.dart';

/// Single row in the Recent Clients list: gradient initials avatar, name,
/// booking status + gallery status chips, and an outstanding-payment
/// badge (or a "Paid" success badge).
class RecentClientTile extends StatelessWidget {
  final ClientData data;

  const RecentClientTile({super.key, required this.data});

  (String, Color) get _galleryLabel {
    switch (data.galleryStatus) {
      case GalleryStatus.delivered:
        return ('Delivered', AppColors.success);
      case GalleryStatus.editing:
        return ('Editing', const Color(0xFFF59E0B));
      case GalleryStatus.notStarted:
        return ('Not Started', AppColors.subtitle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (galleryLabel, galleryColor) = _galleryLabel;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow:
            AppShadows.soft(AppColors.primary, opacity: 0.06, blur: 16, y: 7),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: data.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(15),
            ),
            alignment: Alignment.center,
            child: Text(data.initials,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Chip(label: data.bookingStatus, color: AppColors.primary),
                    _Chip(label: galleryLabel, color: galleryColor),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                data.isPaid ? 'Paid' : 'Due',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: data.isPaid ? AppColors.success : AppColors.error),
              ),
              const SizedBox(height: 2),
              Text(
                data.outstanding,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: data.isPaid ? AppColors.success : AppColors.text,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
