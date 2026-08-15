import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/admin_dashboard_providers.dart';
import '../../widgets/admin/notification_tile.dart';
import '../../widgets/cards/glass_card.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/empty_tab_placeholder.dart';

/// Full Notification List screen — every notification the studio has
/// received, newest first. Reuses the exact [NotificationTile] the
/// Dashboard's inline preview uses, wrapped in [Dismissible] for
/// swipe-to-delete, plus a "Mark all read" action and the shared
/// [EmptyTabPlaceholder] for the empty state. Backed by the same
/// [adminDashboardProvider] as the rest of the app — no separate data
/// source, so read/unread state always stays in sync with the Dashboard.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnapshot = ref.watch(adminDashboardProvider);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Notifications',
        actions: [
          asyncSnapshot.maybeWhen(
            data: (snapshot) => snapshot.unreadNotificationCount > 0
                ? Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: TextButton(
                      onPressed: () => ref
                          .read(adminDashboardProvider.notifier)
                          .markAllNotificationsRead(),
                      child: const Text('Mark all read',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: asyncSnapshot.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (error, _) => const Center(
          child: Text('Could not load notifications',
              style: TextStyle(color: AppColors.subtitle)),
        ),
        data: (snapshot) {
          final notifications = snapshot.notifications;
          if (notifications.isEmpty) {
            return const EmptyTabPlaceholder(
              icon: Icons.notifications_none_rounded,
              title: "You're all caught up",
              message:
                  'New booking, upload and gallery\nupdates will show up here.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
            itemCount: notifications.length,
            itemBuilder: (context, i) {
              final n = notifications[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Dismissible(
                  key: ValueKey(n.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: Colors.white),
                  ),
                  onDismissed: (_) => ref
                      .read(adminDashboardProvider.notifier)
                      .deleteNotification(n.id),
                  child: GlassCard(
                    fillColor: Colors.white.withValues(alpha: 0.7),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: NotificationTile(
                      data: n,
                      isLast: true,
                      onTap: () async {
                        if (!n.isRead) {
                          await ref
                              .read(adminDashboardProvider.notifier)
                              .markNotificationRead(n.id);
                        }
                        if (!context.mounted) return;
                        Navigator.pushNamed(
                            context, AppRoutes.notificationDetail,
                            arguments: n);
                      },
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
