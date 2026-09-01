import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/app_localizations.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_providers.dart';
import '../../providers/settings_provider.dart';
import '../../providers/user_providers.dart';
import '../../services/media_picker_service.dart' show MediaContentType;
import '../../widgets/cards/glass_card.dart';
import '../../widgets/common/snackbar_helper.dart';

/// Profile tab body — account summary (name/email/avatar) is the real,
/// logged-in [AppUser] from [authProvider] (populated from `GET
/// /auth/me` on launch and refreshed here via pull-to-refresh), not
/// local device-only settings — plus a menu of settings rows and a Log
/// Out action that returns to Role Selection. Lives inside
/// [MainNavScreen].
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
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

  bool _isUploadingAvatar = false;

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    XFile? picked;
    try {
      picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
      return;
    }
    if (picked == null) return;

    setState(() => _isUploadingAvatar = true);

    try {
      final bytes = await picked.readAsBytes();
      final contentType = picked.mimeType ?? MediaContentType.forFileName(picked.name);
      
      final newUrl = await ref.read(userRepositoryProvider).uploadAvatar(
            bytes: bytes,
            fileName: picked.name,
            contentType: contentType,
          );
      
      if (!mounted) return;

      if (newUrl != null) {
        final currentUser = ref.read(authProvider).valueOrNull;
        if (currentUser != null) {
          ref.read(authProvider.notifier).setUser(currentUser.copyWith(avatarUrl: newUrl));
        }
        SnackBarHelper.showSuccess(context, 'Profile picture updated successfully.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: ${e is ApiException ? e.message : e}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                GestureDetector(
                  onTap: _pickAndUploadAvatar,
                  child: Stack(
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
                      if (_isUploadingAvatar)
                        Positioned.fill(
                          child: ClipOval(
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.45),
                              child: const Center(
                                child: SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          height: 28,
                          width: 28,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.surface, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
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
          const SizedBox(height: AppSpacing.lg),
          // ── Danger Zone ──────────────────────────────────────────────
          GlassCard(
            fillColor: AppColors.error.withValues(alpha: 0.05),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.22)),
            borderRadius: AppRadius.lg,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _MenuRow(
              icon: Icons.delete_forever_rounded,
              label: 'Delete Account',
              iconColor: AppColors.error,
              labelColor: AppColors.error,
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  barrierColor: Colors.black.withValues(alpha: 0.45),
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    surfaceTintColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg)),
                    icon: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_forever_rounded,
                          color: AppColors.error, size: 28),
                    ),
                    title: const Text('Delete Account?',
                        textAlign: TextAlign.center),
                    content: const Text(
                      'This will permanently delete your account and all associated data. This cannot be undone.',
                      textAlign: TextAlign.center,
                    ),
                    actionsAlignment: MainAxisAlignment.center,
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Continue',
                            style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  Navigator.of(context).pushNamed(AppRoutes.deleteAccount);
                }
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
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