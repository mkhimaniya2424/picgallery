import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/settings_provider.dart';
import '../../../widgets/common/custom_app_bar.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar:
          const CustomAppBar(title: 'Notification Settings', showBack: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _ToggleTile(
              icon: Icons.notifications_active_rounded,
              title: 'Push Notifications',
              value: settings.pushNotifications,
              onChanged: (v) => ref
                  .read(settingsProvider.notifier)
                  .updateSettings(settings.copyWith(pushNotifications: v)),
            ),
            const SizedBox(height: AppSpacing.md),
            _ToggleTile(
              icon: Icons.email_outlined,
              title: 'Email Notifications',
              value: settings.emailNotifications,
              onChanged: (v) => ref
                  .read(settingsProvider.notifier)
                  .updateSettings(settings.copyWith(emailNotifications: v)),
            ),
            const SizedBox(height: AppSpacing.md),
            _ToggleTile(
              icon: Icons.sms_outlined,
              title: 'SMS Alerts',
              value: settings.smsAlerts,
              onChanged: (v) => ref
                  .read(settingsProvider.notifier)
                  .updateSettings(settings.copyWith(smsAlerts: v)),
            ),
          ],
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

  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
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
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
