import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/app_exceptions.dart';
import '../../core/theme/app_theme.dart';
import '../../models/settings_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/settings_provider.dart';
import '../../providers/studio_provider.dart';
import '../../providers/user_providers.dart';
import '../../widgets/common/custom_app_bar.dart';
import 'edit_studio_profile_screen.dart';

class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() =>
      _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  @override
  void initState() {
    super.initState();
    _syncLanguageFromBackend();
  }

  /// App Language is now a real backend User column (`app_language`), but
  /// this whole screen still reads its display value from the local
  /// SettingsModel cache (`settings.language`) everywhere below. Rather
  /// than rewrite every read site, mirror the backend's value down into
  /// that cache once on screen entry — same "prefer cached, refreshMe if
  /// nothing's loaded yet" fallback used by EditStudioProfileScreen.
  Future<void> _syncLanguageFromBackend() async {
    var user = ref.read(authProvider).valueOrNull;
    if (user == null) {
      try {
        await ref.read(authProvider.notifier).refreshMe();
      } on ApiException {
        return;
      }
      if (!mounted) return;
      user = ref.read(authProvider).valueOrNull;
    }
    if (user == null) return;

    final settings = ref.read(settingsProvider);
    if (settings.language != user.appLanguage) {
      await ref
          .read(settingsProvider.notifier)
          .updateSettings(settings.copyWith(language: user.appLanguage));
    }
  }

  void _editGeneralInfo(SettingsModel settings) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditStudioProfileScreen(settings: settings),
      ),
    );
  }

  void _showLanguageSelector(SettingsModel settings) {
    final languages = ['English', 'Hindi', 'Spanish', 'German', 'French'];
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Select Language',
            style:
                TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
        children: languages.map((lang) {
          final isSelected = settings.language == lang;
          return SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final updatedUser = await ref
                    .read(userRepositoryProvider)
                    .updateProfile(appLanguage: lang);
                ref.read(authProvider.notifier).setUser(updatedUser);
                await ref
                    .read(settingsProvider.notifier)
                    .updateSettings(settings.copyWith(language: updatedUser.appLanguage));
              } on ApiException catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving language: ${e.message}')),
                  );
                }
              }
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(lang,
                    style: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.text,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal)),
                if (isSelected)
                  const Icon(Icons.check_rounded,
                      color: AppColors.primary, size: 18),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showQualitySelector(SettingsModel settings) {
    final options = ['Original', 'High'];
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Default Upload Quality',
            style:
                TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
        children: options.map((opt) {
          final isSelected = settings.uploadQuality == opt;
          return SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(settingsProvider.notifier)
                  .updateSettings(settings.copyWith(uploadQuality: opt));
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(opt,
                    style: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.text,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal)),
                if (isSelected)
                  const Icon(Icons.check_rounded,
                      color: AppColors.primary, size: 18),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showThemeSelector(SettingsModel settings) {
    final options = ['Light', 'Dark', 'System'];
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Select Theme',
            style:
                TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
        children: options.map((opt) {
          final isSelected = settings.themeMode == opt;
          return SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(settingsProvider.notifier)
                  .updateSettings(settings.copyWith(themeMode: opt));
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(opt,
                    style: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.text,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal)),
                if (isSelected)
                  const Icon(Icons.check_rounded,
                      color: AppColors.primary, size: 18),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _setupSecurityPin(SettingsModel settings) {
    showDialog(
      context: context,
      builder: (context) => _SetupSecurityPinDialog(settings: settings, ref: ref),
    );
  }

  void _triggerBackup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const _BackupProgressDialog();
      },
    );
  }

  void _triggerRestore() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Restore Backup',
            style:
                TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
        content: const Text(
            'Do you want to restore the latest backup archive? This will overwrite current temporary configurations.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.subtitle)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const _RestoreProgressDialog(),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Restore',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'PicGallery',
      applicationVersion: 'v2.1.4-Release',
      applicationLegalese: '© 2026 PicGallery Studio. All Rights Reserved.',
      children: const [
        Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
              'Designed as a state-of-the-art photography sharing and proofing ecosystem for pro photographers and studios.',
              style: TextStyle(color: AppColors.subtitle, fontSize: 12.5)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final user = ref.watch(authProvider).valueOrNull;
    final studioSubtitle = [
      user?.studioName ?? settings.studioName,
      user?.fullName ?? settings.photographerName,
    ].where((s) => s.isNotEmpty).join(' • ');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: 'Studio Settings', showBack: true),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // 1. GENERAL ACCOUNT
          _buildSectionHeader('General Info'),
          _buildSettingsCard([
            _SettingsRow(
              icon: Icons.storefront_rounded,
              title: 'Studio Identity',
              subtitle: studioSubtitle,
              onTap: () => _editGeneralInfo(settings),
            ),
            _SettingsRow(
              icon: Icons.translate_rounded,
              title: 'App Language',
              subtitle: settings.language,
              onTap: () => _showLanguageSelector(settings),
            ),
          ]),
          const SizedBox(height: AppSpacing.md),

          // 2. PREFERENCES
          _buildSectionHeader('Preferences'),
          _buildSettingsCard([
            _SettingsRow(
              icon: Icons.palette_rounded,
              title: 'App Theme',
              subtitle: settings.themeMode,
              onTap: () => _showThemeSelector(settings),
            ),
            _SettingsToggleRow(
              icon: Icons.wifi_rounded,
              title: 'Wi-Fi Only Uploads',
              value: settings.wifiOnlyUploads,
              onChanged: (val) async {
                await ref
                    .read(settingsProvider.notifier)
                    .updateSettings(settings.copyWith(wifiOnlyUploads: val));
              },
            ),
            _SettingsRow(
              icon: Icons.image_search_rounded,
              title: 'Upload Resolution',
              subtitle: settings.uploadQuality,
              onTap: () => _showQualitySelector(settings),
            ),
          ]),
          const SizedBox(height: AppSpacing.md),


          // 4. PRIVACY & SECURITY
          _buildSectionHeader('Security & Privacy'),
          _buildSettingsCard([
            _SettingsRow(
              icon: Icons.lock_outline_rounded,
              title: 'App Lock PIN',
              subtitle:
                  settings.securityPinEnabled ? 'PIN Enabled' : 'PIN Disabled',
              onTap: () => _setupSecurityPin(settings),
            ),
            // Only shown once a PIN actually exists — this toggle controls
            // whether that PIN is *required at launch*, which is a
            // separate concept from whether a PIN is set at all. Previously
            // this reused `securityPinEnabled` itself, so toggling it would
            // have silently disabled the PIN instead of just the
            // launch-enforcement behavior.
            if (settings.securityPinEnabled)
              _SettingsToggleRow(
                icon: Icons.fingerprint_rounded,
                title: 'Require PIN on Launch',
                value: settings.requirePinOnLaunch,
                onChanged: (val) async {
                  await ref.read(settingsProvider.notifier).updateSettings(
                      settings.copyWith(requirePinOnLaunch: val));
                },
              ),
            _SettingsToggleRow(
              icon: Icons.visibility_off_outlined,
              title: 'Private Studio Profile',
              value: settings.privateProfile,
              onChanged: (val) async {
                await ref
                    .read(settingsProvider.notifier)
                    .updateSettings(settings.copyWith(privateProfile: val));
              },
            ),
            _SettingsToggleRow(
              icon: Icons.search_off_rounded,
              title: 'Search Engine Indexing',
              value: settings.searchEngineIndexing,
              onChanged: (val) async {
                await ref.read(settingsProvider.notifier).updateSettings(
                    settings.copyWith(searchEngineIndexing: val));
              },
            ),
            _SettingsRow(
              icon: Icons.verified_user_outlined,
              title: 'App Permissions',
              subtitle: 'Camera, photo library & notifications',
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.permissions),
            ),
          ]),
          const SizedBox(height: AppSpacing.md),

          // 5. SYSTEM BACKUP & DETAILS
          _buildSectionHeader('System Utilities'),
          _buildSettingsCard([
            _SettingsRow(
              icon: Icons.backup_rounded,
              title: 'Cloud Backup Now',
              subtitle: 'Save config preferences to Hive cloud',
              onTap: _triggerBackup,
            ),
            _SettingsRow(
              icon: Icons.restore_rounded,
              title: 'Restore Database',
              subtitle: 'Restore previous configurations',
              onTap: _triggerRestore,
            ),
            _SettingsRow(
              icon: Icons.delete_sweep_rounded,
              title: 'Trash / Deleted Media',
              subtitle: 'Manage soft-deleted items and empty trash',
              onTap: () =>
                  Navigator.of(context).pushNamed(AppRoutes.adminTrash),
            ),
            _SettingsRow(
              icon: Icons.info_outline_rounded,
              title: 'About App',
              subtitle: 'v2.1.4-Release info & legal',
              onTap: _showAboutDialog,
            ),
          ]),
          const SizedBox(height: AppSpacing.lg),

          // LOGOUT & DANGER ZONE
          _buildSettingsCard([
            _SettingsRow(
              icon: Icons.logout_rounded,
              title: 'Log Out',
              iconColor: AppColors.error,
              titleColor: AppColors.error,
              showChevron: false,
              onTap: () async {
                final navigator = Navigator.of(context);
                // Clear the persisted token/session first — previously this
                // button only navigated away and left the auth token intact,
                // so the studio was never actually logged out.
                try {
                  await ref.read(authProvider.notifier).logout();
                } catch (_) {
                  // Best-effort: still navigate away even if some part of
                  // logout (e.g. clearing the cached Google session) fails.
                }
                navigator.pushNamedAndRemoveUntil(
                    AppRoutes.roleSelection, (route) => false);
              },
            ),
          ]),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final Color? titleColor;
  final bool showChevron;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    this.titleColor,
    this.showChevron = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? AppColors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: titleColor ?? AppColors.text),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.subtitle,
                            fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
            ),
            if (showChevron)
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.subtitle, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggleRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _SetupSecurityPinDialog extends StatefulWidget {
  final SettingsModel settings;
  final WidgetRef ref;

  const _SetupSecurityPinDialog({required this.settings, required this.ref});

  @override
  State<_SetupSecurityPinDialog> createState() => _SetupSecurityPinDialogState();
}

class _SetupSecurityPinDialogState extends State<_SetupSecurityPinDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _pinCtrl;

  @override
  void initState() {
    super.initState();
    _pinCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      title: Text(
          widget.settings.securityPinEnabled
              ? 'Change Security PIN'
              : 'Setup App Lock PIN',
          style: const TextStyle(
              color: AppColors.text, fontWeight: FontWeight.bold)),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _pinCtrl,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          decoration: const InputDecoration(
              labelText: '4-Digit PIN', hintText: '••••'),
          validator: (v) {
            if (v == null || v.trim().length != 4) {
              return 'PIN must be 4 digits';
            }
            if (int.tryParse(v) == null) {
              return 'PIN must contain numbers only';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.subtitle)),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final updated = widget.settings.copyWith(
                securityPinEnabled: true,
                securityPin: _pinCtrl.text.trim(),
              );
              navigator.pop();
              await widget.ref
                  .read(settingsProvider.notifier)
                  .updateSettings(updated);
              messenger.showSnackBar(
                const SnackBar(
                    content: Text('App Lock PIN set successfully')),
              );
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Enable',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

enum _BackupStatus { inProgress, success, error }

/// Backup-progress dialog wired to the real `POST /studios/me/backup`
/// call (Task 6.5) — sends the current [SettingsModel] as-is via
/// [StudioProfileRepository.createBackup]. `ConsumerStatefulWidget` so
/// it can read `settingsProvider`/`studioProfileRepositoryProvider`
/// itself rather than the caller threading them through as
/// constructor args. Error handling mirrors `_showLanguageSelector`'s
/// try/catch-`ApiException` shape, plus a Retry action since this
/// dialog (unlike the language selector's snackbar) stays open long
/// enough to offer one.
class _BackupProgressDialog extends ConsumerStatefulWidget {
  const _BackupProgressDialog();

  @override
  ConsumerState<_BackupProgressDialog> createState() => _BackupProgressDialogState();
}

class _BackupProgressDialogState extends ConsumerState<_BackupProgressDialog> {
  _BackupStatus _status = _BackupStatus.inProgress;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _runBackup();
  }

  Future<void> _runBackup() async {
    setState(() {
      _status = _BackupStatus.inProgress;
      _errorMessage = null;
    });

    final settings = ref.read(settingsProvider);
    try {
      await ref.read(studioProfileRepositoryProvider).createBackup(settings.toJson());
      if (!mounted) return;
      setState(() => _status = _BackupStatus.success);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _BackupStatus.error;
        _errorMessage = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isError = _status == _BackupStatus.error;
    final isDone = _status == _BackupStatus.success;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        isError ? 'Backup Failed' : 'Backing Up Data',
        style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isError
                ? (_errorMessage ?? 'Something went wrong. Please try again.')
                : isDone
                    ? 'Your studio settings backup has been saved.'
                    : 'Backing up your studio settings and configurations...',
            style: const TextStyle(color: AppColors.subtitle, fontSize: 13.5),
          ),
          if (!isError) ...[
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: isDone ? 1.0 : null,
              color: AppColors.primary,
              backgroundColor: AppColors.border,
            ),
            const SizedBox(height: 8),
            Text(
              isDone ? '100% Completed' : 'Uploading…',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        if (isError) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.subtitle)),
          ),
          ElevatedButton(
            onPressed: _runBackup,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text(
              'Retry',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ] else if (isDone)
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text(
              'Finish',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}

enum _RestoreStatus { inProgress, success, error, notFound }

/// Mirrors [_BackupProgressDialog]'s shape (Task 7): fetches the latest
/// backup via `GET /studios/me/backup` (`getLatestBackup()`), applies its
/// payload to [settingsProvider] so the restored values actually take
/// effect and persist locally, and only reports success once that's done
/// — never on a hardcoded timer.
class _RestoreProgressDialog extends ConsumerStatefulWidget {
  const _RestoreProgressDialog();

  @override
  ConsumerState<_RestoreProgressDialog> createState() => _RestoreProgressDialogState();
}

class _RestoreProgressDialogState extends ConsumerState<_RestoreProgressDialog> {
  _RestoreStatus _status = _RestoreStatus.inProgress;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _runRestore();
  }

  Future<void> _runRestore() async {
    setState(() {
      _status = _RestoreStatus.inProgress;
      _errorMessage = null;
    });

    try {
      final backup = await ref.read(studioProfileRepositoryProvider).getLatestBackup();
      final restoredSettings = SettingsModel.fromJson(backup.payload);
      await ref.read(settingsProvider.notifier).updateSettings(restoredSettings);
      if (!mounted) return;
      setState(() => _status = _RestoreStatus.success);
    } on NotFoundException {
      if (!mounted) return;
      setState(() => _status = _RestoreStatus.notFound);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _RestoreStatus.error;
        _errorMessage = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isError = _status == _RestoreStatus.error;
    final isNotFound = _status == _RestoreStatus.notFound;
    final isDone = _status == _RestoreStatus.success;
    final isFailure = isError || isNotFound;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        isNotFound
            ? 'No Backup Found'
            : isError
                ? 'Restore Failed'
                : 'Restoring Data',
        style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isNotFound
                ? 'This studio has never made a backup, so there is nothing to restore yet.'
                : isError
                    ? (_errorMessage ?? 'Something went wrong. Please try again.')
                    : isDone
                        ? 'Your studio settings have been restored from the latest backup.'
                        : 'Fetching your latest backup and restoring settings...',
            style: const TextStyle(color: AppColors.subtitle, fontSize: 13.5),
          ),
          if (!isFailure) ...[
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: isDone ? 1.0 : null,
              color: AppColors.primary,
              backgroundColor: AppColors.border,
            ),
            const SizedBox(height: 8),
            Text(
              isDone ? '100% Completed' : 'Restoring…',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        if (isNotFound) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.subtitle)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _triggerBackupFromDialogContext();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text(
              'Back Up Now',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ] else if (isError) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.subtitle)),
          ),
          ElevatedButton(
            onPressed: _runRestore,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text(
              'Retry',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ] else if (isDone)
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text(
              'Finish',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  /// Reuses the same backup flow the "Cloud Backup Now" row triggers, so
  /// tapping "Back Up Now" from the "nothing to restore yet" state doesn't
  /// need a second, slightly-different code path.
  void _triggerBackupFromDialogContext() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _BackupProgressDialog(),
    );
  }
}