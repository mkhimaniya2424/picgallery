import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin_dashboard_data.dart';
import '../../providers/admin_dashboard_providers.dart';
import '../../widgets/admin/activity_timeline_tile.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/empty_tab_placeholder.dart';

/// Full Activity Timeline — every studio event (uploads, albums,
/// clients, bookings, shared galleries, profile changes, QR check-ins,
/// reports), newest first, with a type filter. Reuses the exact same
/// [ActivityTimelineList] rows the Dashboard's inline preview shows —
/// just fed the full (optionally filtered) log instead of a section that
/// scrolls off-screen with everything else.
class RecentActivityScreen extends ConsumerStatefulWidget {
  const RecentActivityScreen({super.key});

  @override
  ConsumerState<RecentActivityScreen> createState() =>
      _RecentActivityScreenState();
}

class _RecentActivityScreenState extends ConsumerState<RecentActivityScreen> {
  ActivityType? _filter;

  @override
  Widget build(BuildContext context) {
    final asyncSnapshot = ref.watch(adminDashboardProvider);

    return Scaffold(
      appBar: const CustomAppBar(title: 'Recent Activity'),
      body: asyncSnapshot.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (error, _) => const Center(
          child: Text('Could not load activity',
              style: TextStyle(color: AppColors.subtitle)),
        ),
        data: (snapshot) {
          final entries = _filter == null
              ? snapshot.activityLog
              : snapshot.activityLog.where((e) => e.type == _filter).toList();

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(adminDashboardProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
              children: [
                _TypeFilterRow(
                    selected: _filter,
                    onSelected: (t) => setState(() => _filter = t)),
                const SizedBox(height: AppSpacing.md),
                if (snapshot.activityLog.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.xxl),
                    child: EmptyTabPlaceholder(
                      icon: Icons.history_rounded,
                      title: 'No activity yet',
                      message:
                          'Every upload, booking and client update\nwill show up here as it happens.',
                    ),
                  )
                else if (entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.xxl),
                    child: Text(
                      'No matching activity for this filter',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.subtitle),
                    ),
                  )
                else
                  ActivityTimelineList(entries: entries),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Horizontal type-filter chips — same visual language as
/// [SearchFilterChips] (gradient-filled when selected, glass pill when
/// not) so filtering feels consistent across the app, even though the
/// underlying enum ([ActivityType]) is different.
class _TypeFilterRow extends StatelessWidget {
  final ActivityType? selected;
  final ValueChanged<ActivityType?> onSelected;

  const _TypeFilterRow({required this.selected, required this.onSelected});

  String _label(ActivityType? type) {
    if (type == null) return 'All';
    switch (type) {
      case ActivityType.upload:
        return 'Uploads';
      case ActivityType.album:
        return 'Albums';
      case ActivityType.client:
        return 'Clients';

      case ActivityType.gallery:
        return 'Galleries';
      case ActivityType.profile:
        return 'Profile';
      case ActivityType.qr:
        return 'QR Scans';
      case ActivityType.report:
        return 'Reports';
    }
  }

  @override
  Widget build(BuildContext context) {
    final types = [null, ...ActivityType.values];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: types.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final type = types[i];
          final isSelected = selected == type;
          return InkWell(
            onTap: () => onSelected(type),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: AnimatedContainer(
              duration: AppDurations.fast,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected ? AppColors.buttonGradient : null,
                color: isSelected ? null : Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                    color: isSelected ? Colors.transparent : AppColors.border),
              ),
              child: Text(
                _label(type),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.subtitle,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
