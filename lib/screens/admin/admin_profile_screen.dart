import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/cards/glass_card.dart';

/// Studio owner profile tab — account summary + settings menu + Log Out.
/// The name/studio header reads from [authProvider] — the real,
/// backend-fetched [AppUser] (`GET /auth/me`) that's also the single
/// source of truth for login/session state — instead of any local or
/// in-memory dashboard mock, so it's never a disconnected static string.
class AdminProfileScreen extends ConsumerWidget {
  const AdminProfileScreen({super.key});

  static const _menu = [
    (icon: Icons.storefront_rounded, label: 'Studio Settings'),
    (icon: Icons.download_rounded, label: 'Download History'),
    (icon: Icons.help_outline_rounded, label: 'Help & Support'),
  ];


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final name = user?.fullName.trim() ?? '';
    final studio = user?.studioName?.trim() ?? '';
    final avatarUrl = user?.avatarUrl ?? '';

    final hasName = name.isNotEmpty;
    final hasStudio = studio.isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkBackground
          : AppColors.background,
      body: RefreshIndicator(
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
                        : Text(
                            hasName ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w700),
                          ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(hasName ? name : 'Set up your profile',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(hasStudio ? studio : 'Set up your studio profile',
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
                    label: item.label,
                    showDivider: i != _menu.length - 1,
                    onTap: () {
                      if (item.label == 'Studio Settings') {
                        Navigator.of(context).pushNamed(AppRoutes.adminSettings);
                      } else if (item.label == 'Download History') {
                        Navigator.of(context).pushNamed(AppRoutes.downloadHistory);
                      } else if (item.label == 'Help & Support') {
                        Navigator.of(context).pushNamed(AppRoutes.helpSupport);
                      } else {

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${item.label} coming soon')),
                        );
                      }
                    },
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
                label: 'Log Out',
                iconColor: AppColors.error,
                labelColor: AppColors.error,
                showDivider: false,
                onTap: () => Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.roleSelection, (route) => false),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool showDivider;
  final Color? iconColor;
  final Color? labelColor;
  final VoidCallback? onTap;

  const _MenuRow({
    required this.icon,
    required this.label,
    this.showDivider = true,
    this.iconColor,
    this.labelColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
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
        ),
        if (showDivider) Divider(height: 1, color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkBorder : AppColors.border),
      ],
    );
  }
}