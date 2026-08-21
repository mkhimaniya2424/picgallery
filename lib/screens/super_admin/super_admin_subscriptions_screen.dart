import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import 'super_admin_models.dart';
import 'super_admin_user_detail_screen.dart';

/// Cross-cutting view of "which studios currently pay a platform
/// subscription" — pulled from the same Studio Users data but
/// filtered/sorted around `subscriptionStatus` instead of profile
/// info. Maps to `Transaction` rows in the backend where
/// `payment_type == subscription` (studio -> platform payments).
class SuperAdminSubscriptionsScreen extends StatefulWidget {
  const SuperAdminSubscriptionsScreen({super.key});

  @override
  State<SuperAdminSubscriptionsScreen> createState() =>
      _SuperAdminSubscriptionsScreenState();
}

class _SuperAdminSubscriptionsScreenState
    extends State<SuperAdminSubscriptionsScreen> {
  SubscriptionStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final studios = SuperAdminMockData.studios
        .where((s) => _filter == null || s.subscriptionStatus == _filter)
        .toList();

    final counts = {
      for (final status in SubscriptionStatus.values)
        status: SuperAdminMockData.studios
            .where((s) => s.subscriptionStatus == status)
            .length,
    };

    return Scaffold(
      
      appBar: AppBar(
        
        elevation: 0,
        title: const Text('Subscriptions',
            style: TextStyle(
                color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              children: [
                _FilterChip(
                  label: 'All',
                  count: SuperAdminMockData.studios.length,
                  selected: _filter == null,
                  color: AppColors.text,
                  onTap: () => setState(() => _filter = null),
                ),
                for (final status in SubscriptionStatus.values)
                  _FilterChip(
                    label: status.label,
                    count: counts[status] ?? 0,
                    selected: _filter == status,
                    color: status.color,
                    onTap: () => setState(() => _filter = status),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: studios.isEmpty
                ? const Center(
                    child: Text('No studios in this filter',
                        style: TextStyle(color: AppColors.subtitle)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
                    itemCount: studios.length,
                    itemBuilder: (context, i) =>
                        _SubscriptionTile(studio: studios[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: selected ? color : AppColors.border),
          ),
          child: Text('$label · $count',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? color : AppColors.subtitle)),
        ),
      ),
    );
  }
}

class _SubscriptionTile extends StatelessWidget {
  final PlatformUser studio;
  const _SubscriptionTile({required this.studio});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SuperAdminUserDetailScreen(userId: studio.id),
        )),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: studio.subscriptionStatus.color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(studio.studioName ?? studio.fullName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13.5)),
                    Text(studio.email,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.subtitle)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: studio.subscriptionStatus.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(studio.subscriptionStatus.label,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: studio.subscriptionStatus.color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
