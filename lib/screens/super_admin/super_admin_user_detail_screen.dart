import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import 'super_admin_models.dart';

/// Detail view for a single Studio or Client account.
///
/// The important part: if this email ALSO has an account under the
/// other role (`user.linkedAccountId != null` — see
/// `super_admin_models.dart` for how that's determined from the
/// backend's `uq_users_email_role` constraint), a "Linked account"
/// card appears so the admin can see and jump to it, instead of the
/// two rows looking unrelated. Nothing is auto-merged — they stay two
/// separate accounts/records, same as they are in the database; this
/// screen just makes the relationship visible.
class SuperAdminUserDetailScreen extends StatelessWidget {
  final String userId;
  const SuperAdminUserDetailScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final user = SuperAdminMockData.findById(userId);
    if (user == null) {
      return const Scaffold(body: Center(child: Text('User not found')));
    }
    final isStudio = user.type == PlatformUserType.studio;
    final linked = user.linkedAccountId != null
        ? SuperAdminMockData.findById(user.linkedAccountId!)
        : null;

    return Scaffold(
      
      appBar: AppBar(
        
        elevation: 0,
        title: Text(isStudio ? 'Studio account' : 'Client account',
            style: const TextStyle(
                color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(user.initials,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 12),
                Text(user.fullName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(user.email,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                if (isStudio) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(user.subscriptionStatus.label,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (linked != null) ...[
            _LinkedAccountCard(current: user, linked: linked),
            const SizedBox(height: AppSpacing.md),
          ],
          _InfoCard(
            title: 'Profile',
            rows: [
              _InfoRow('Phone', user.phone),
              _InfoRow('City', user.city),
              if (isStudio) _InfoRow('Studio name', user.studioName ?? '—'),
              _InfoRow('Joined',
                  '${user.joinedAt.day}/${user.joinedAt.month}/${user.joinedAt.year}'),
              _InfoRow('Role', isStudio ? 'Photographer / Studio' : 'Client'),
            ],
          ),
          if (isStudio) ...[
            const SizedBox(height: AppSpacing.md),
            _InfoCard(
              title: 'Subscription',
              rows: [
                _InfoRow('Status', user.subscriptionStatus.label),
                const _InfoRow('Plan', 'Studio Pro (mock)'),
                const _InfoRow('Next billing', '—'),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm)),
                  ),
                  child: const Text('Suspend account',
                      style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LinkedAccountCard extends StatelessWidget {
  final PlatformUser current;
  final PlatformUser linked;
  const _LinkedAccountCard({required this.current, required this.linked});

  @override
  Widget build(BuildContext context) {
    final linkedIsStudio = linked.type == PlatformUserType.studio;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.link_rounded, color: AppColors.secondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Same email, other role',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.text)),
                const SizedBox(height: 2),
                Text(
                  'This email also has a ${linkedIsStudio ? "Studio" : "Client"} account'
                  '${linkedIsStudio ? " (${linked.studioName})" : ""}.',
                  style: const TextStyle(fontSize: 12, color: AppColors.subtitle),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (_) => SuperAdminUserDetailScreen(userId: linked.id),
              ));
            },
            child: const Text('View',
                style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<_InfoRow> rows;
  const _InfoCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text)),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(fontSize: 12.5, color: AppColors.subtitle)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.text)),
          ),
        ],
      ),
    );
  }
}
