import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin_dashboard_data.dart';

/// Automatically generated, newest-first log of everything that just
/// happened in the studio (photo uploaded, album created, client added,
/// booking confirmed, gallery shared, profile updated...). Every entry
/// comes straight from [AdminDashboardSnapshot.activityLog] — nothing
/// here is hardcoded.
class ActivityTimelineList extends StatelessWidget {
  final List<ActivityEntry> entries;

  const ActivityTimelineList({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'No activity yet — try a Quick Action above',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.subtitle),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm, horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 10)),
        ],
      ),
      child: AnimatedSize(
        duration: AppDurations.medium,
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          children: List.generate(entries.length, (i) {
            final entry = entries[i];
            return _ActivityRow(
              key: ValueKey(entry.id),
              entry: entry,
              isLast: i == entries.length - 1,
            );
          }),
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final ActivityEntry entry;
  final bool isLast;

  const _ActivityRow({super.key, required this.entry, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final (icon, gradient) = entry.style;
    return AnimatedContainer(
      duration: AppDurations.medium,
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
          top: AppSpacing.sm, bottom: isLast ? AppSpacing.sm : AppSpacing.sm),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: Colors.white, size: 16),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(entry.title,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text)),
                        ),
                        Text(entry.time,
                            style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.subtitle)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(entry.subtitle,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.subtitle)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
