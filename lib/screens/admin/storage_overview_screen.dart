import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin_dashboard_data.dart';
import '../../providers/admin_dashboard_providers.dart';
import '../../widgets/admin/analytics_summary_card.dart';
import '../../widgets/admin/recent_album_card.dart';
import '../../widgets/admin/recent_upload_card.dart';
import '../../widgets/admin/section_header.dart';
import '../../widgets/admin/storage_usage_card.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/empty_state_card.dart';

/// Full Storage Overview — the deeper breakdown behind the Dashboard's
/// compact [StorageUsageCard]: total usage, a Photos/Videos/Albums/Shared
/// split, and the heaviest uploads. Everything is derived live from the
/// same [AdminDashboardSnapshot] the Dashboard already watches (via
/// [adminDashboardProvider]), so these numbers can never drift out of
/// sync with the summary card that links here.
class StorageOverviewScreen extends ConsumerWidget {
  const StorageOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnapshot = ref.watch(adminDashboardProvider);

    return Scaffold(
      appBar: const CustomAppBar(title: 'Storage Overview'),
      body: asyncSnapshot.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (error, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text('Could not load storage data',
                style: TextStyle(color: AppColors.subtitle)),
          ),
        ),
        data: (snapshot) => RefreshIndicator(
          onRefresh: () => ref.read(adminDashboardProvider.notifier).refresh(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 700;
              final summaryColumns = constraints.maxWidth >= 900
                  ? 4
                  : constraints.maxWidth >= 600
                      ? 3
                      : 2;

              StatCardData stat(String label) => snapshot.stats.firstWhere(
                    (s) => s.label == label,
                    orElse: () => snapshot.stats.first,
                  );
              final storageStat = stat('Storage Used');
              final photos = stat('Total Photos');
              final videos = stat('Total Videos');

              final albumUploads =
                  snapshot.recentUploads.where((u) => !u.isVideo).toList();
              final heaviest = [...snapshot.recentUploads]
                ..sort((a, b) => b.mediaCount.compareTo(a.mediaCount));

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
                children: [
                  StorageUsageCard(
                    usedLabel: storageStat.value,
                    totalLabel: '',
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionHeader(title: 'Breakdown', actionLabel: null),
                  const SizedBox(height: AppSpacing.md),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: summaryColumns,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 1.35,
                    children: [
                      AnalyticsSummaryCard(
                          label: photos.label,
                          value: photos.value,
                          icon: photos.icon,
                          gradient: photos.gradient),
                      AnalyticsSummaryCard(
                          label: videos.label,
                          value: videos.value,
                          icon: videos.icon,
                          gradient: videos.gradient),
                      AnalyticsSummaryCard(
                        label: 'Albums',
                        value: '${albumUploads.length}',
                        icon: Icons.photo_album_rounded,
                        gradient: const [Color(0xFF7C5CFF), Color(0xFFEC4899)],
                      ),
                      AnalyticsSummaryCard(
                        label: 'Shared Galleries',
                        value: '${snapshot.sharedGalleryCount}',
                        icon: Icons.ios_share_rounded,
                        gradient: const [Color(0xFF22C55E), Color(0xFF7C5CFF)],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionHeader(
                      title: 'Heaviest Uploads', actionLabel: null),
                  const SizedBox(height: AppSpacing.md),
                  heaviest.isEmpty
                      ? const EmptyStateCard(
                          icon: Icons.cloud_off_rounded,
                          message: 'No uploads yet — storage is empty')
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: heaviest.length > 6 ? 6 : heaviest.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isWide ? 4 : 2,
                            mainAxisSpacing: AppSpacing.md,
                            crossAxisSpacing: AppSpacing.md,
                            childAspectRatio: 0.82,
                          ),
                          itemBuilder: (_, i) =>
                              RecentUploadCard(data: heaviest[i]),
                        ),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionHeader(
                      title: 'Albums Using Storage', actionLabel: null),
                  const SizedBox(height: AppSpacing.md),
                  albumUploads.isEmpty
                      ? const EmptyStateCard(message: 'No albums yet')
                      : SizedBox(
                          height: 116,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: albumUploads.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: AppSpacing.sm),
                            itemBuilder: (_, i) =>
                                RecentAlbumCard(data: albumUploads[i]),
                          ),
                        ),
                  const SizedBox(height: AppSpacing.xl),
                  Builder(
                    builder: (context) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          gradient: isDark ? null : AppColors.softWash,
                          color: isDark ? AppColors.darkSurface : null,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.workspace_premium_rounded,
                                color: AppColors.primary),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                'Running low on space? Upgrade your studio plan for more storage.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.textOnDark : AppColors.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}