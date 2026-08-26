import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_providers.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/cards/glass_card.dart';

/// Profile tab body — account summary (name/email/avatar) is the real,
/// logged-in [AppUser] from [authProvider] (populated from `GET
/// /auth/me` on launch and refreshed here via pull-to-refresh), not
/// local device-only settings — plus a menu of settings rows and a Log
/// Out action that returns to Role Selection. Lives inside
/// [MainNavScreen].
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  // "Collections" and "Download History" removed: GET /collections and
  // GET /download-history are studio-only (get_current_studio_user) and
  // 403 for a client account — same reason they were already stripped
  // from client_drawer.dart. Re-add if a client-scoped route ever
  // exists for either.
  static const _menu = [
    (icon: Icons.person_outline_rounded, label: 'Edit Profile'),
    (icon: Icons.favorite_rounded, label: 'Favorite Studios'),
    (icon: Icons.lock_outline_rounded, label: 'Privacy & Security'),
    (icon: Icons.verified_user_outlined, label: 'App Permissions'),
    (icon: Icons.info_outline_rounded, label: 'About'),
    (icon: Icons.help_outline_rounded, label: 'Help & Support'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final l10n = AppLocalizations.of(context)!;
    final name = user?.fullName.trim() ?? '';
    final email = user?.email.trim() ?? '';
    final avatarUrl = user?.avatarUrl ?? '';

    String getMenuLabel(String label) {
      switch (label) {
        case 'Edit Profile':
          return l10n.editProfile;
        case 'Privacy & Security':
          return l10n.privacySecurity;
        case 'About':
          return l10n.about;
        case 'Help & Support':
          return l10n.helpSupport;
        default:
          return label;
      }
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(authProvider.notifier).refreshMe(),
      child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 26,
                          offset: const Offset(0, 12)),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: avatarUrl.isNotEmpty
                      ? ClipOval(
                          child: avatarUrl.startsWith('http')
                              ? Image.network(avatarUrl, fit: BoxFit.cover, width: 88, height: 88)
                              : Image.file(File(avatarUrl), fit: BoxFit.cover, width: 88, height: 88),
                        )
                      : const Icon(Icons.person_rounded,
                          color: Colors.white, size: 40),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(name.isEmpty ? 'Add your name' : name,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(email.isEmpty ? 'No email set' : email,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          GlassCard(
            borderRadius: AppRadius.lg,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: List.generate(_menu.length, (i) {
                final item = _menu[i];
                return _MenuRow(
                  icon: item.icon,
                  label: getMenuLabel(item.label),
                  onTap: item.label == 'Favorite Studios'
                      ? () => Navigator.of(context).pushNamed(
                            AppRoutes.favoriteStudios,
                          )
                      : item.label == 'Edit Profile'
                          ? () => Navigator.of(context).pushNamed(
                                AppRoutes.editProfile,
                              )
                          : item.label == 'Privacy & Security'
                              ? () => Navigator.of(context).pushNamed(
                                    '/profile/privacy',
                                  )
                              : item.label == 'App Permissions'
                                  ? () => Navigator.of(context).pushNamed(
                                        AppRoutes.permissions,
                                      )
                                  : item.label == 'About'
                                      ? () => Navigator.of(context)
                                          .pushNamed('/profile/about')
                                      : item.label == 'Help & Support'
                                          ? () => Navigator.of(context)
                                              .pushNamed(AppRoutes.helpSupport)
                                          : null,
                );
              }),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlassCard(
            borderRadius: AppRadius.lg,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _MenuRow(
              icon: Icons.logout_rounded,
              label: l10n.logOut,
              iconColor: AppColors.error,
              labelColor: AppColors.error,
              onTap: () async {
                // Clear the real session (token + cached AppUser) *and*
                // the locally-persisted identity fields — leaving
                // either behind is what let a previous account's cached
                // name/email survive into the next account's session on
                // the same device. Only the identity fields are reset,
                // not the whole settings cache, so device prefs like
                // theme/language survive a logout.
                await ref.read(authProvider.notifier).logout();
                final currentSettings = ref.read(settingsProvider);
                await ref.read(settingsProvider.notifier).updateSettings(
                      currentSettings.copyWith(
                        photographerName: '',
                        email: '',
                        clientId: '',
                      ),
                    );
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRoutes.roleSelection, (route) => false);
                }
              },
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;
  final Color? labelColor;
  final VoidCallback? onTap;

  const _MenuRow({
    required this.icon,
    required this.label,
    this.iconColor,
    this.labelColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? AppColors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: labelColor ?? Theme.of(context).colorScheme.onSurface),
              ),
            ),
            if (labelColor == null)
              Icon(Icons.chevron_right_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}