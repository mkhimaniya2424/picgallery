import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/admin_dashboard_providers.dart';
import '../../widgets/admin/quick_action_handler.dart';
import '../../widgets/admin/quick_action_tile.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/empty_state_card.dart';

/// Full Quick Actions screen — every action from the Dashboard's compact
/// 4-column grid (Upload Photos/Videos, Create Album, Add Client, Share
/// Gallery, Scan QR, Bookings, Reports), laid out larger and responsively.
/// Reuses the exact same [QuickActionTile] widget and, via
/// [QuickActionHandler], the exact same mutation/dialog logic the
/// Dashboard uses — so an action performed here behaves identically to
/// tapping it on the Dashboard.
class QuickActionsScreen extends ConsumerWidget {
  const QuickActionsScreen({super.key});

  void _toast(BuildContext context, String message, {Color? color}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: color ?? AppColors.text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnapshot = ref.watch(adminDashboardProvider);

    return Scaffold(
      appBar: const CustomAppBar(title: 'Quick Actions'),
      body: asyncSnapshot.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (error, _) => const Center(
          child: Text('Could not load quick actions',
              style: TextStyle(color: AppColors.subtitle)),
        ),
        data: (snapshot) {
          final actions = snapshot.quickActions;
          if (actions.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: EmptyStateCard(
                  icon: Icons.bolt_rounded,
                  message: 'No quick actions available'),
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 900
                  ? 5
                  : constraints.maxWidth >= 600
                      ? 4
                      : 3;
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
                itemCount: actions.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisExtent: 128,
                ),
                itemBuilder: (context, i) {
                  final action = actions[i];
                  return QuickActionTile(
                    data: action,
                    // No onNavigateToTab here — this screen is reached
                    // via Navigator.pushNamed, not the IndexedStack
                    // AdminMainNavScreen owns, so there's no bottom-nav
                    // tab to switch. QuickActionHandler falls back to a
                    // toast for the actions that would otherwise need it.
                    onTap: () => QuickActionHandler.execute(
                      context: context,
                      ref: ref,
                      action: action,
                      toast: (msg, {color}) =>
                          _toast(context, msg, color: color),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}