import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin_dashboard_data.dart';
import '../../providers/admin_dashboard_providers.dart';
import '../../widgets/buttons/gradient_button.dart';
import '../../widgets/cards/glass_card.dart';
import '../../widgets/common/custom_app_bar.dart';

/// Full detail view for a single notification, opened from
/// [NotificationsScreen] (or the Dashboard's inline preview). Shows the
/// same type-specific gradient icon language as [NotificationTile], the
/// full un-truncated title/subtitle, an exact timestamp, and a Delete
/// action that pops back to the list.
class NotificationDetailScreen extends ConsumerWidget {
  final NotificationData notification;

  const NotificationDetailScreen({super.key, required this.notification});

  (IconData, List<Color>, String) _style(NotificationType type) {
    switch (type) {
      case NotificationType.reminder:
        return (
          Icons.alarm_rounded,
          const [Color(0xFF7C5CFF), Color(0xFFA855F7)],
          'Reminder'
        );
      case NotificationType.approval:
        return (
          Icons.rate_review_rounded,
          const [Color(0xFFF59E0B), Color(0xFFEC4899)],
          'Approval'
        );

      case NotificationType.gallery:
        return (
          Icons.visibility_rounded,
          const [Color(0xFFA855F7), Color(0xFFEC4899)],
          'Gallery'
        );
    }
  }

  String _fullTimestamp(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} • $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, gradient, typeLabel) = _style(notification.type);

    return Scaffold(
      appBar: const CustomAppBar(title: 'Notification'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassCard(
              fillColor: Colors.white.withValues(alpha: 0.75),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: gradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                                color: gradient.last.withValues(alpha: 0.32),
                                blurRadius: 16,
                                offset: const Offset(0, 8))
                          ],
                        ),
                        child: Icon(icon, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: gradient.first.withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(typeLabel,
                                  style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: gradient.first)),
                            ),
                            const SizedBox(height: 6),
                            Text(_fullTimestamp(notification.createdAt),
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.subtitle)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(notification.title,
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    notification.subtitle,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.subtitle,
                        height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            GradientButton(
              label: 'Delete Notification',
              icon: Icons.delete_outline_rounded,
              gradient: const LinearGradient(
                  colors: [AppColors.error, Color(0xFFEC4899)]),
              onPressed: () async {
                await ref
                    .read(adminDashboardProvider.notifier)
                    .deleteNotification(notification.id);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
