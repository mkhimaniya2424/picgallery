import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import 'super_admin_models.dart';
import 'super_admin_user_detail_screen.dart';

/// One screen, three tabs: Studio Users / Client Users / Website Users.
/// Keeping them as tabs (instead of three separate screens) makes the
/// "same email in two places" relationship easy to notice — an admin
/// searching an email sees it show up under both Studio and Client
/// tabs at once.
class SuperAdminUsersScreen extends StatefulWidget {
  final int initialTab;
  const SuperAdminUsersScreen({super.key, this.initialTab = 0});

  @override
  State<SuperAdminUsersScreen> createState() => _SuperAdminUsersScreenState();
}

class _SuperAdminUsersScreenState extends State<SuperAdminUsersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 3, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      appBar: AppBar(
        
        elevation: 0,
        title: const Text('Users',
            style: TextStyle(
                color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.subtitle,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Studio'),
            Tab(text: 'Client'),
            Tab(text: 'Website'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by name or email',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.subtitle),
                filled: true,
                fillColor: AppColors.surfaceElevated,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _StudioList(query: _query),
                _ClientList(query: _query),
                _WebsiteLeadList(query: _query),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioList extends StatelessWidget {
  final String query;
  const _StudioList({required this.query});

  @override
  Widget build(BuildContext context) {
    final items = SuperAdminMockData.studios.where((u) =>
        u.fullName.toLowerCase().contains(query) ||
        u.email.toLowerCase().contains(query) ||
        (u.studioName ?? '').toLowerCase().contains(query));
    if (items.isEmpty) return const _EmptyList(label: 'No studios found');
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
      itemCount: items.length,
      itemBuilder: (context, i) => _UserTile(user: items.elementAt(i)),
    );
  }
}

class _ClientList extends StatelessWidget {
  final String query;
  const _ClientList({required this.query});

  @override
  Widget build(BuildContext context) {
    final items = SuperAdminMockData.clients.where((u) =>
        u.fullName.toLowerCase().contains(query) ||
        u.email.toLowerCase().contains(query));
    if (items.isEmpty) return const _EmptyList(label: 'No clients found');
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
      itemCount: items.length,
      itemBuilder: (context, i) => _UserTile(user: items.elementAt(i)),
    );
  }
}

class _WebsiteLeadList extends StatelessWidget {
  final String query;
  const _WebsiteLeadList({required this.query});

  @override
  Widget build(BuildContext context) {
    final items = SuperAdminMockData.websiteLeads.where((l) =>
        l.name.toLowerCase().contains(query) ||
        l.email.toLowerCase().contains(query));
    if (items.isEmpty) return const _EmptyList(label: 'No leads found');
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final lead = items.elementAt(i);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
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
                backgroundColor: AppColors.gold.withValues(alpha: 0.16),
                child: const Icon(Icons.person_outline_rounded,
                    color: AppColors.gold, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lead.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13.5)),
                    Text(lead.email,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.subtitle)),
                    const SizedBox(height: 2),
                    Text('via ${lead.source}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.subtitle)),
                  ],
                ),
              ),
              if (lead.convertedToAccount)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: const Text('Converted',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success)),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _UserTile extends StatelessWidget {
  final PlatformUser user;
  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final isStudio = user.type == PlatformUserType.studio;
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
          builder: (_) => SuperAdminUserDetailScreen(userId: user.id),
        )),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(user.fullName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13.5)),
                        ),
                        if (user.linkedAccountId != null) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.link_rounded,
                              size: 14, color: AppColors.secondary),
                        ],
                      ],
                    ),
                    Text(
                        isStudio
                            ? (user.studioName ?? user.email)
                            : user.email,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.subtitle)),
                  ],
                ),
              ),
              if (isStudio)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: user.subscriptionStatus.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(user.subscriptionStatus.label,
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: user.subscriptionStatus.color)),
                )
              else
                const Icon(Icons.chevron_right_rounded, color: AppColors.subtitle),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  final String label;
  const _EmptyList({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(label, style: const TextStyle(color: AppColors.subtitle)),
    );
  }
}
