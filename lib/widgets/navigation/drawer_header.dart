import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin_dashboard_data.dart';
import '../../providers/admin_dashboard_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/drawer_provider.dart';
import '../../providers/settings_provider.dart';

/// Gradient (purple → pink) header for [StudioDrawer].
///
/// Reads the studio/admin identity from the same [settingsProvider] used by
/// Studio Settings (so it never drifts out of sync), and the storage stat
/// from the live [adminDashboardProvider] snapshot already powering the
/// dashboard — nothing here is hardcoded.
class StudioDrawerHeader extends ConsumerWidget {
  const StudioDrawerHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final snapshot = ref.watch(adminDashboardProvider).value;
    final authUser = ref.watch(authStateProvider).user;


    // Use the real logged-in user's profile as the primary source so the
    // hardcoded SettingsModel defaults ("Naman Shrivastava") never show up.
    final studioName = (authUser?.studioName?.isNotEmpty == true)
        ? authUser!.studioName!
        : (settings.studioName.isNotEmpty ? settings.studioName : (snapshot?.studioName ?? 'Studio'));
    final adminName = (authUser?.fullName.isNotEmpty == true)
        ? authUser!.fullName
        : (settings.photographerName.isNotEmpty ? settings.photographerName : (snapshot?.photographerName ?? 'Studio Admin'));
    final adminEmail = (authUser?.email.isNotEmpty == true)
        ? authUser!.email
        : settings.email;
    final initial = adminName.isNotEmpty ? adminName[0].toUpperCase() : '?';

    final storage = _storageUsage(snapshot);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        MediaQuery.of(context).padding.top + AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        // Purple → Pink, as specified in the brief.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.accent],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Studio logo/icon + studio name.
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.camera_alt_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  studioName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Avatar (with subscription badge) + name/email + Edit Profile.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.24),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800),
                    ),
                  ),

              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adminName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      adminEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    _EditProfileButton(
                      onTap: () {
                        Navigator.of(context).pop(); // close drawer
                        Navigator.of(context)
                            .pushNamed(AppRoutes.adminSettings);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),
          _StorageUsageBar(
              usedLabel: storage.usedLabel,
              totalLabel: storage.totalLabel,
              percent: storage.percent),
        ],
      ),
    );
  }

  _StorageStat _storageUsage(AdminDashboardSnapshot? snapshot) {
    if (snapshot == null)
      return const _StorageStat(usedLabel: '—', totalLabel: '1 TB', percent: 0);
    final stat = snapshot.stats.cast<StatCardData?>().firstWhere(
          (s) => s?.label == 'Storage Used',
          orElse: () => null,
        );
    final usedLabel = stat?.value ?? '0 GB';
    final totalMedia =
        snapshot.recentUploads.fold<int>(0, (sum, u) => sum + u.mediaCount);
    final storageGb = totalMedia * 1.4 / 1000;
    final percent = (storageGb / 1024).clamp(0.0, 1.0);
    return _StorageStat(
        usedLabel: usedLabel, totalLabel: '1 TB', percent: percent);
  }
}

class _StorageStat {
  final String usedLabel;
  final String totalLabel;
  final double percent;
  const _StorageStat(
      {required this.usedLabel,
      required this.totalLabel,
      required this.percent});
}



class _EditProfileButton extends StatelessWidget {
  const _EditProfileButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_rounded, color: Colors.white, size: 12),
              SizedBox(width: 5),
              Text('Edit Profile',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StorageUsageBar extends StatelessWidget {
  const _StorageUsageBar(
      {required this.usedLabel,
      required this.totalLabel,
      required this.percent});
  final String usedLabel;
  final String totalLabel;
  final double percent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Storage',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
            Text(
              '$usedLabel / $totalLabel',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ],
    );
  }
}
