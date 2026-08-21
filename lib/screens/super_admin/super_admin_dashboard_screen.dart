import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import 'super_admin_models.dart';
import 'super_admin_subscriptions_screen.dart';
import 'super_admin_users_screen.dart';

/// Home screen of the Super Admin panel — platform-wide numbers across
/// every studio and every client, not scoped to one studio the way
/// `screens/admin/admin_dashboard_screen.dart` (Studio Owner's own
/// dashboard) is.
class SuperAdminDashboardScreen extends StatelessWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final studios = SuperAdminMockData.studios;
    final clients = SuperAdminMockData.clients;
    final leads = SuperAdminMockData.websiteLeads;
    final activeSubs =
        studios.where((s) => s.subscriptionStatus == SubscriptionStatus.active).length;

    return Scaffold(
      
      appBar: AppBar(
        
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: AppSpacing.md,
        title: const Text(
          'Super Admin',
          style: TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w700,
            fontSize: 19,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.subtitle),
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.35,
            children: [
              _Kpi(
                icon: Icons.photo_camera_back_rounded,
                gradient: const [AppColors.primary, AppColors.secondary],
                label: 'Studio users',
                value: '${studios.length}',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SuperAdminUsersScreen(initialTab: 0),
                )),
              ),
              _Kpi(
                icon: Icons.people_alt_rounded,
                gradient: const [AppColors.secondary, AppColors.accent],
                label: 'Client users',
                value: '${clients.length}',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SuperAdminUsersScreen(initialTab: 1),
                )),
              ),
              _Kpi(
                icon: Icons.travel_explore_rounded,
                gradient: const [AppColors.accent, AppColors.gold],
                label: 'Website leads',
                value: '${leads.length}',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SuperAdminUsersScreen(initialTab: 2),
                )),
              ),
              _Kpi(
                icon: Icons.workspace_premium_rounded,
                gradient: const [AppColors.success, AppColors.primary],
                label: 'Active subscriptions',
                value: '$activeSubs',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SuperAdminSubscriptionsScreen(),
                )),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Recently joined',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...[...studios, ...clients]
              .toList()
              .also((l) => l.sort((a, b) => b.joinedAt.compareTo(a.joinedAt)))
              .take(4)
              .map((u) => _RecentUserTile(user: u)),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Dual-role accounts',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
          ),
          const SizedBox(height: 4),
          const Text(
            'Same email registered as both a Studio and a Client account.',
            style: TextStyle(fontSize: 12.5, color: AppColors.subtitle),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...SuperAdminMockData.allUsers
              .where((u) => u.linkedAccountId != null)
              .map((u) => _RecentUserTile(user: u, showLinkedBadge: true)),
        ],
      ),
    );
  }
}

extension _Also<T> on T {
  T also(void Function(T) f) {
    f(this);
    return this;
  }
}

class _Kpi extends StatelessWidget {
  final IconData icon;
  final List<Color> gradient;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _Kpi({
    required this.icon,
    required this.gradient,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: gradient.last.withValues(alpha: 0.10),
                blurRadius: 20,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 19),
            ),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.subtitle, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _RecentUserTile extends StatelessWidget {
  final PlatformUser user;
  final bool showLinkedBadge;

  const _RecentUserTile({required this.user, this.showLinkedBadge = false});

  @override
  Widget build(BuildContext context) {
    final isStudio = user.type == PlatformUserType.studio;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor:
                (isStudio ? AppColors.primary : AppColors.accent).withValues(alpha: 0.12),
            child: Text(user.initials,
                style: TextStyle(
                    color: isStudio ? AppColors.primary : AppColors.accent,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                Text(user.email,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.subtitle)),
              ],
            ),
          ),
          if (showLinkedBadge)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: const Text('linked',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary)),
            )
          else
            Text(isStudio ? 'Studio' : 'Client',
                style: const TextStyle(fontSize: 11, color: AppColors.subtitle)),
        ],
      ),
    );
  }
}
