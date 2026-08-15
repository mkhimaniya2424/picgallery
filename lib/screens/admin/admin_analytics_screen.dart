import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin_dashboard_data.dart';
import '../../providers/admin_dashboard_providers.dart';
import '../../widgets/admin/activity_timeline_tile.dart';
import '../../widgets/admin/analytics_chart_card.dart';
import '../../widgets/admin/section_header.dart';
import '../../widgets/admin/stat_card.dart';
import '../../widgets/common/empty_state_card.dart';
import '../../widgets/common/loading_widget.dart';

/// Studio Reports & Analytics — fully dynamic, sliver-based analytics
/// screen. Every number, chart and list on this screen comes straight
/// from [adminDashboardProvider] (backed by [AdminDashboardSnapshot]);
/// nothing here is hardcoded or randomly generated.
///
/// Layout uses [NestedScrollView] with a pinned [SliverAppBar] + [TabBar]
/// and a [CustomScrollView] per tab, so every tab scrolls independently
/// with no nested-scroll conflicts and no RenderFlex/viewport overflow.
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

enum _ClientMetric { views, downloads }

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(adminDashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.background,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.text, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Studio Reports & Analytics',
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.1),
            ),
            centerTitle: true,
            bottom: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.subtitle,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Views'),
                Tab(text: 'Downloads'),
                Tab(text: 'Activity'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          physics: const BouncingScrollPhysics(),
          children: [
            _buildOverviewTab(dashboardAsync),
            _buildViewsTab(dashboardAsync),
            _buildDownloadsTab(dashboardAsync),
            _buildActivityTab(dashboardAsync),
          ],
        ),
      ),
    );
  }

  // ── SHARED LOADING / ERROR / EMPTY STATES ──────────────────────────────
  // Every tab is its own independently-scrollable CustomScrollView, even
  // while loading/erroring/empty, so pull gestures never conflict with the
  // outer NestedScrollView.

  Widget _statusScrollView(Widget child) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverFillRemaining(hasScrollBody: false, child: child),
      ],
    );
  }

  Widget _buildLoadingState() {
    return _statusScrollView(
      const Center(child: LoadingWidget(message: 'Loading analytics…')),
    );
  }

  Widget _buildErrorState(Object error) {
    return _statusScrollView(
      Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 40),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Could not load your analytics\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.subtitle, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: () =>
                    ref.read(adminDashboardProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return _statusScrollView(
      Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 12)),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'No analytics available',
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.subtitle,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: () =>
                    ref.read(adminDashboardProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1. OVERVIEW TAB ─────────────────────────────────────────────────

  Widget _buildOverviewTab(AsyncValue<AdminDashboardSnapshot> asyncValue) {
    return asyncValue.when(
      loading: _buildLoadingState,
      error: (err, _) => _buildErrorState(err),
      data: (snapshot) {
        final hasAnyData = snapshot.stats.isNotEmpty ||
            snapshot.analytics.isNotEmpty ||
            snapshot.clients.isNotEmpty;
        if (!hasAnyData) {
          return _buildEmptyState(
            icon: Icons.insights_rounded,
            message:
                'Studio analytics will appear here once you have activity.',
          );
        }

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
              sliver: SliverToBoxAdapter(
                child: SectionHeader(title: 'Studio KPIs', actionLabel: null),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
              sliver: snapshot.stats.isEmpty
                  ? const SliverToBoxAdapter(
                      child: EmptyStateCard(
                          icon: Icons.bar_chart_rounded,
                          message: 'No studio stats yet'),
                    )
                  : SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _statsCrossAxisCount(context),
                        mainAxisSpacing: AppSpacing.md,
                        crossAxisSpacing: AppSpacing.md,
                        mainAxisExtent: 180,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => StatCard(data: snapshot.stats[i]),
                        childCount: snapshot.stats.length,
                      ),
                    ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SectionHeader(
                      title: 'Performance Trends', actionLabel: null),
                  const SizedBox(height: AppSpacing.md),
                  _buildAnalyticsCarousel(snapshot),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionHeader(
                      title: 'Gallery Leaderboards', actionLabel: null),
                  const SizedBox(height: AppSpacing.md),
                  _buildClientMetricList(
                    snapshot,
                    metric: _ClientMetric.views,
                    limit: 3,
                    emptyMessage: 'No client engagement yet',
                  ),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  int _statsCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 900) return 4;
    if (width >= 600) return 3;
    return 2;
  }

  Widget _buildAnalyticsCarousel(AdminDashboardSnapshot snapshot) {
    if (snapshot.analytics.isEmpty) {
      return const EmptyStateCard(
          icon: Icons.insights_rounded,
          message: 'No performance trend data yet');
    }
    return SizedBox(
      height: 216,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: snapshot.analytics.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, i) =>
            AnalyticsChartCard(series: snapshot.analytics[i]),
      ),
    );
  }

  // ── 2. VIEWS TAB ─────────────────────────────────────────────────────

  Widget _buildViewsTab(AsyncValue<AdminDashboardSnapshot> asyncValue) {
    return asyncValue.when(
      loading: _buildLoadingState,
      error: (err, _) => _buildErrorState(err),
      data: (snapshot) {
        if (snapshot.clients.isEmpty && snapshot.analytics.isEmpty) {
          return _buildEmptyState(
            icon: Icons.visibility_rounded,
            message:
                'View activity will appear here once clients start opening galleries.',
          );
        }

        // Use the studio-wide total from the backend (sum of ShareLink.views_count)
        // rather than summing per-client which was always 0 since the connections
        // API doesn't carry individual view counts.
        final totalViews = snapshot.totalGalleryViews;
        final viewsSeries = _findSeries(snapshot, 'Gallery Views');

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.md),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildMetricBanner(
                    title: 'Total Views',
                    value: '$totalViews',
                    gradient: const [Color(0xFF7C5CFF), Color(0xFFA855F7)],
                    trendSeries: viewsSeries,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: viewsSeries != null
                        ? AnalyticsChartCard(series: viewsSeries)
                        : const EmptyStateCard(
                            icon: Icons.show_chart_rounded,
                            message: 'No views trend data yet'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'Most Active Clients (Views)',
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildClientMetricList(
                    snapshot,
                    metric: _ClientMetric.views,
                    emptyMessage: 'No client views recorded yet',
                  ),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── 3. DOWNLOADS TAB ────────────────────────────────────────────────

  Widget _buildDownloadsTab(AsyncValue<AdminDashboardSnapshot> asyncValue) {
    return asyncValue.when(
      loading: _buildLoadingState,
      error: (err, _) => _buildErrorState(err),
      data: (snapshot) {
        if (snapshot.clients.isEmpty) {
          return _buildEmptyState(
            icon: Icons.download_rounded,
            message:
                'Download activity will appear here once clients start downloading photos.',
          );
        }

        // Use the studio-wide total from the backend (count of DownloadEvent rows)
        // rather than summing per-client totals, which required per-viewer
        // attribution that the DownloadEvent table does support per connected client.
        final totalDownloads = snapshot.totalGalleryDownloads;

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.md),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildMetricBanner(
                    title: 'Total Downloads',
                    value: '$totalDownloads',
                    gradient: const [Color(0xFFEC4899), Color(0xFFF472B6)],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const EmptyStateCard(
                      icon: Icons.show_chart_rounded,
                      message: 'No downloads trend data yet'),
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'Clients by Downloads',
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildClientMetricList(
                    snapshot,
                    metric: _ClientMetric.downloads,
                    emptyMessage: 'No client downloads recorded yet',
                  ),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── 4. ACTIVITY TAB ─────────────────────────────────────────────────
  // Replaces the old "Reactions" tab (likes/comments were never backed
  // by real data) with the studio's real, ever-growing Activity Timeline.

  Widget _buildActivityTab(AsyncValue<AdminDashboardSnapshot> asyncValue) {
    return asyncValue.when(
      loading: _buildLoadingState,
      error: (err, _) => _buildErrorState(err),
      data: (snapshot) {
        if (snapshot.activityLog.isEmpty) {
          return _buildEmptyState(
            icon: Icons.timeline_rounded,
            message:
                'Activity will show up here as clients and your studio take action.',
          );
        }
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.md),
              sliver: SliverToBoxAdapter(
                child: ActivityTimelineList(entries: snapshot.activityLog),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── SHARED HELPERS ───────────────────────────────────────────────────

  /// Finds a real [AnalyticsSeries] by title, or null if the snapshot
  /// doesn't have one — used instead of ever fabricating chart data.
  AnalyticsSeries? _findSeries(AdminDashboardSnapshot snapshot, String title) {
    for (final series in snapshot.analytics) {
      if (series.title == title) return series;
    }
    return null;
  }

  /// Gradient summary banner. The trend chip is only shown when a real
  /// [AnalyticsSeries] is supplied to derive a genuine period-over-period
  /// delta from — never a fabricated percentage.
  Widget _buildMetricBanner({
    required String title,
    required String value,
    required List<Color> gradient,
    AnalyticsSeries? trendSeries,
  }) {
    double? deltaPct;
    if (trendSeries != null && trendSeries.values.length >= 2) {
      final last = trendSeries.values.last;
      final prev = trendSeries.values[trendSeries.values.length - 2];
      deltaPct = prev == 0 ? null : ((last - prev) / prev) * 100;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
              ],
            ),
          ),
          if (deltaPct != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                      deltaPct >= 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: Colors.white,
                      size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${deltaPct >= 0 ? '+' : ''}${deltaPct.toStringAsFixed(0)}%',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Real clients ranked by a real metric (views or downloads) straight
  /// off [ClientData] — no seeded/fake leaderboard entries. Rendered as a
  /// plain (non-scrolling) Column since the list is always small and
  /// already lives inside a scrollable sliver — avoids nesting a second
  /// scrollable inside the tab's CustomScrollView.
  Widget _buildClientMetricList(
    AdminDashboardSnapshot snapshot, {
    required _ClientMetric metric,
    required String emptyMessage,
    int? limit,
  }) {
    final sorted = [...snapshot.clients]..sort((a, b) {
        final aVal =
            metric == _ClientMetric.views ? a.totalViews : a.totalDownloads;
        final bVal =
            metric == _ClientMetric.views ? b.totalViews : b.totalDownloads;
        return bVal.compareTo(aVal);
      });
    final list = limit != null ? sorted.take(limit).toList() : sorted;

    if (list.isEmpty) {
      return EmptyStateCard(
          icon: Icons.people_alt_rounded, message: emptyMessage);
    }

    return Column(
      children: [
        for (var i = 0; i < list.length; i++) ...[
          _ClientRankTile(
            rank: i + 1,
            client: list[i],
            value: metric == _ClientMetric.views
                ? list[i].totalViews
                : list[i].totalDownloads,
            valueLabel: metric == _ClientMetric.views ? 'views' : 'downloads',
          ),
          if (i != list.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

/// Ranked client row used by the Gallery Leaderboards / Views / Downloads
/// lists — always driven by real [ClientData], never seeded content.
class _ClientRankTile extends StatelessWidget {
  final int rank;
  final ClientData client;
  final int value;
  final String valueLabel;

  const _ClientRankTile({
    required this.rank,
    required this.client,
    required this.value,
    required this.valueLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: rank == 1
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                  : AppColors.border,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: TextStyle(
                color: rank == 1 ? const Color(0xFFD97706) : AppColors.subtitle,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: client.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              client.initials,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  client.bookingStatus,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.subtitle,
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$value $valueLabel',
            style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
