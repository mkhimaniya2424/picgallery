import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/user_providers.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/custom_app_bar.dart';

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  // True while a PATCH /users/me for allow_downloads is in flight — keeps
  // the toggle disabled so a second tap can't race the first.
  bool _savingDownloads = false;

  /// Persists the "Download Permissions" toggle server-side
  /// (`User.allow_downloads`, PATCH /users/me) and pushes the returned
  /// user straight into [authProvider] so it — and every other screen
  /// reading it — reflects the change immediately, matching
  /// [EditProfileScreen]'s save flow. Server-persisted (not
  /// [settingsProvider]/Hive) so it survives reinstalls and is visible
  /// to the backend, same as `push_notifications_enabled`.
  Future<void> _handleAllowDownloadsChanged(bool value) async {
    setState(() => _savingDownloads = true);
    try {
      final updated = await ref.read(userRepositoryProvider).updateProfile(allowDownloads: value);
      ref.read(authProvider.notifier).setUser(updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _savingDownloads = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final allowDownloads = ref.watch(authProvider).valueOrNull?.allowDownloads ?? true;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Privacy & Security', showBack: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _ToggleTile(
              icon: Icons.lock_outline_rounded,
              title: 'Account Privacy',
              value: settings.privateProfile,
              onChanged: (v) => ref
                  .read(settingsProvider.notifier)
                  .updateSettings(settings.copyWith(privateProfile: v)),
            ),
            const SizedBox(height: AppSpacing.md),
            _ToggleTile(
              icon: Icons.download_for_offline_rounded,
              title: 'Download Permissions',
              value: allowDownloads,
              disabled: _savingDownloads,
              onChanged: _handleAllowDownloadsChanged,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: TextButton.icon(
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.deleteAccount);
            },
            icon: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
            label: const Text(
              'Delete Account',
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                side: const BorderSide(color: AppColors.error),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool disabled;

  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: disabled ? null : onChanged,
          ),
        ],
      ),
    );
  }
}