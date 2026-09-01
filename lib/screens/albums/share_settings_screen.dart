import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routes/app_routes.dart';
import '../../models/share_link_model.dart';
import '../../providers/album_provider.dart';
import '../../providers/share_link_provider.dart';
import '../../widgets/buttons/gradient_button.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/inputs/custom_text_field.dart';

class ShareSettingsScreen extends ConsumerStatefulWidget {
  final String albumId;

  const ShareSettingsScreen({super.key, required this.albumId});

  @override
  ConsumerState<ShareSettingsScreen> createState() => _ShareSettingsScreenState();
}

class _ShareSettingsScreenState extends ConsumerState<ShareSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  bool _initialized = false;
  bool _isPublic = true;
  String? _selectedClientId;
  bool _hasExpiry = false;
  DateTime? _expiryDate;
  bool _allowDownload = true;
  bool _showWatermark = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _generateRandomPasscode() {
    final rand = Random.secure();
    final passcode = (100000 + rand.nextInt(900000)).toString();
    setState(() {
      _passwordController.text = passcode;
    });
  }

  /// Primes the form from the loaded link, once.
  void _initFields(GalleryShareLink? link) {
    if (_initialized) return;
    _initialized = true;

    if (link != null && !link.isRevoked) {
      _isPublic = !link.hasPassword;
      _selectedClientId = link.clientId;
      _hasExpiry = link.expiresAt != null;
      _expiryDate = link.expiresAt;
      _allowDownload = link.allowDownload;
      _showWatermark = link.showWatermark;
    }
  }

  Future<void> _selectExpiryDate(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = _expiryDate ?? now.add(const Duration(days: 7));
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(now) ? now : initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _expiryDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      });
    }
  }

  /// Returns true when [widget.albumId] is a real server-side UUID (e.g.
  /// `3fa85f64-5717-4562-b3fc-2c963f66afa6`) rather than a local placeholder
  /// the old in-memory / Hive-only implementation stamped on new albums
  /// (e.g. `al-<microseconds>`). Only backend-synced albums can have share
  /// links — the server-side `POST /share-links` will always 404 for a
  /// placeholder id because no matching row exists in the database.
  bool get _isBackendSynced {
    // UUIDs are exactly 36 chars: 8-4-4-4-12 hex digits + 4 hyphens.
    final id = widget.albumId;
    if (id.length != 36) return false;
    // Quick regex check — avoids depending on a UUID package.
    return RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false)
        .hasMatch(id);
  }

  Future<void> _saveSettings(GalleryShareLink? existingLink) async {
    final hasExistingPassword = existingLink != null && !existingLink.isRevoked && existingLink.hasPassword;

    if (!_isPublic && !hasExistingPassword && !_formKey.currentState!.validate()) {
      return;
    }
    if (!_isPublic && hasExistingPassword && _passwordController.text.isNotEmpty) {
      if (!_formKey.currentState!.validate()) return;
    }

    setState(() => _isSaving = true);
    try {
      if (!_isBackendSynced) {
        // This album was created while the app was running in offline /
        // demo mode and never synced to the server. Share links require a
        // real backend album. Ask the user to re-create the album.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This album was created in offline mode and cannot be shared yet. '
              'Please delete it and recreate it while connected to sync it to the server.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      final controller = ref.read(shareLinkControllerProvider(widget.albumId).notifier);
      await controller.createOrUpdate(
        clientId: _isPublic ? null : _selectedClientId,
        clearClient: _isPublic || _selectedClientId == null,
        password: _isPublic
            ? null
            : (_passwordController.text.isEmpty ? null : _passwordController.text),
        clearPassword: _isPublic,
        expiresAt: _hasExpiry ? _expiryDate : null,
        clearExpiry: !_hasExpiry,
        allowDownload: _allowDownload,
        showWatermark: _showWatermark,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Share settings updated successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't update share settings: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _revokeLink() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke Share Link?'),
        content: const Text(
          'This will immediately make the link inactive. Clients will no longer be able to access the gallery.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(shareLinkControllerProvider(widget.albumId).notifier).revoke();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Share link revoked.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't revoke link: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final albums = ref.watch(albumProvider).allAlbums;
    final album = albums.firstWhere((a) => a.id == widget.albumId);

    final linkState = ref.watch(shareLinkControllerProvider(widget.albumId));
    final activeLink = linkState.activeLink;
    final hasActiveLink = activeLink != null && !activeLink.isRevoked;

    _initFields(activeLink);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Share "${album.name}"',
        showBack: true,
      ),
      body: SafeArea(
        child: linkState.isLoading && activeLink == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!_isBackendSynced) ...[
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.cloud_off_rounded, color: Colors.orange, size: 20),
                                      const SizedBox(width: AppSpacing.sm),
                                      const Expanded(
                                        child: Text(
                                          'This album was created offline and hasn\'t been synced to the server. '
                                          'Delete it and recreate it while connected to enable sharing.',
                                          style: TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                              ],
                              _buildSectionHeader(context, 'Gallery Type'),
                              const SizedBox(height: AppSpacing.sm),
                              _buildGalleryTypeSelector(),
                              const SizedBox(height: AppSpacing.lg),
                              if (!_isPublic) ...[
                                _buildSectionHeader(context, 'Security Settings'),
                                const SizedBox(height: AppSpacing.sm),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: CustomTextField(
                                        label: hasActiveLink && activeLink.hasPassword
                                            ? 'New Passcode (leave blank to keep current)'
                                            : 'Passcode',
                                        icon: Icons.lock_outline_rounded,
                                        controller: _passwordController,
                                        obscureText: false,
                                        validator: (v) {
                                          if (hasActiveLink && activeLink.hasPassword && (v == null || v.isEmpty)) {
                                            return null;
                                          }
                                          if (v == null || v.trim().length < 4) {
                                            return 'Passcode must be at least 4 characters';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: OutlinedButton.icon(
                                        onPressed: _generateRandomPasscode,
                                        icon: const Icon(Icons.refresh_rounded, size: 16),
                                        label: const Text('Regenerate'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.lg),
                              ],
                              _buildSectionHeader(context, 'Link Configuration'),
                              const SizedBox(height: AppSpacing.sm),
                              _buildLinkSettingsCard(),
                              const SizedBox(height: AppSpacing.xl),
                              GradientButton(
                                label: hasActiveLink ? 'Update Settings' : 'Generate Share Link',
                                isLoading: _isSaving,
                                onPressed: (_isSaving || !_isBackendSynced) ? null : () => _saveSettings(activeLink),
                              ),
                              if (hasActiveLink) ...[
                                const SizedBox(height: AppSpacing.xxl),
                                const Divider(color: AppColors.border),
                                const SizedBox(height: AppSpacing.lg),
                                _buildSectionHeader(context, 'Active Share Link'),
                                const SizedBox(height: AppSpacing.sm),
                                _buildActiveLinkCard(activeLink),
                                const SizedBox(height: AppSpacing.xl),
                                _buildSectionHeader(context, 'Link Analytics & QR'),
                                const SizedBox(height: AppSpacing.sm),
                                _buildAnalyticsAndQrCard(activeLink),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w800,
        color: isDark ? AppColors.textOnDark : AppColors.text,
      ),
    );
  }

  Widget _buildGalleryTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          RadioListTile<bool>(
            value: true,
            groupValue: _isPublic,
            title: const Text(
              'Public Gallery',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
            ),
            subtitle: const Text(
              'Anyone with the link can view and browse the photos.',
              style: TextStyle(fontSize: 12, color: AppColors.subtitle),
            ),
            activeColor: AppColors.primary,
            onChanged: (val) {
              if (val != null) setState(() => _isPublic = val);
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          RadioListTile<bool>(
            value: false,
            groupValue: _isPublic,
            title: const Text(
              'Private Gallery',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
            ),
            subtitle: const Text(
              'Requires entering a passcode to validate access.',
              style: TextStyle(fontSize: 12, color: AppColors.subtitle),
            ),
            activeColor: AppColors.primary,
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _isPublic = val;
                  if (!_isPublic && _passwordController.text.isEmpty) {
                    _generateRandomPasscode();
                  }
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLinkSettingsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          SwitchListTile(
            value: _hasExpiry,
            title: const Text(
              'Set Expiry Date',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.text),
            ),
            subtitle: const Text(
              'Link will automatically expire after the date.',
              style: TextStyle(fontSize: 11.5, color: AppColors.subtitle),
            ),
            activeThumbColor: AppColors.primary,
            onChanged: (val) {
              setState(() {
                _hasExpiry = val;
                if (val && _expiryDate == null) {
                  _expiryDate = DateTime.now().add(const Duration(days: 7));
                }
              });
            },
          ),
          if (_hasExpiry)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.subtitle),
                  const SizedBox(width: 8),
                  Text(
                    _expiryDate == null
                        ? 'No date selected'
                        : '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.text),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _selectExpiryDate(context),
                    child: const Text('Change Date'),
                  ),
                ],
              ),
            ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          SwitchListTile(
            value: _allowDownload,
            title: const Text(
              'Allow Downloads',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.text),
            ),
            subtitle: const Text(
              'Clients can download high-res original photos.',
              style: TextStyle(fontSize: 11.5, color: AppColors.subtitle),
            ),
            activeThumbColor: AppColors.primary,
            onChanged: (val) => setState(() => _allowDownload = val),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          SwitchListTile(
            value: _showWatermark,
            title: const Text(
              'Overlay Watermark',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.text),
            ),
            subtitle: const Text(
              'Display a soft "picgallery" brand watermarking over photos.',
              style: TextStyle(fontSize: 11.5, color: AppColors.subtitle),
            ),
            activeThumbColor: AppColors.primary,
            onChanged: (val) => setState(() => _showWatermark = val),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveLinkCard(GalleryShareLink link) {
    final primaryUrl = link.primaryShareUrl;
    debugPrint('[SHARE_DEBUG] Original shareId (token): ${link.token}');
    debugPrint('[SHARE_DEBUG] Generated share URL: $primaryUrl');
    debugPrint('[SHARE_DEBUG] QR encoded URL: $primaryUrl');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  primaryUrl,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
                tooltip: 'Copy Link',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: primaryUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('HTTPS Share Link copied to clipboard.')),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.share_rounded, color: AppColors.primary),
                tooltip: 'Share',
                onPressed: () {
                  Share.share(primaryUrl, subject: 'Check out this shared gallery!');
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      AppRoutes.sharedGallery,
                      arguments: SharedGalleryArgs(token: link.token, isPreview: true),
                    );
                  },
                  icon: const Icon(Icons.remove_red_eye_outlined),
                  label: const Text('Preview Client View'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  onPressed: _revokeLink,
                  icon: const Icon(Icons.link_off_rounded),
                  label: const Text('Revoke Link'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsAndQrCard(GalleryShareLink link) {
    final statusColor = link.isExpired
        ? Colors.orange
        : (link.isRevoked ? AppColors.error : AppColors.success);
    final statusText = link.isExpired
        ? 'Expired'
        : (link.isRevoked ? 'Revoked' : 'Active');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Link Analytics',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.text),
                ),
                const SizedBox(height: AppSpacing.md),
                _buildAnalyticRow(Icons.info_outline_rounded, 'Status', statusText, valueColor: statusColor),
                _buildAnalyticRow(Icons.visibility_outlined, 'Total Views', '${link.viewsCount}'),
                _buildAnalyticRow(Icons.download_outlined, 'Downloads', '${link.downloadsCount}'),
                _buildAnalyticRow(
                    Icons.lock_clock_outlined, 'Type', link.hasPassword ? 'Private (Protected)' : 'Public'),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: QrImageView(
                  // Encodes the HTTPS universal link: works in camera scanner apps,
                  // opens native App directly via App Links / Universal Links, or
                  // falls back to browser Web Client Gallery when app is not installed.
                  data: link.primaryShareUrl,
                  version: QrVersions.auto,
                  size: 110.0,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Scan QR to Share',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.subtitle),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.subtitle),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.subtitle),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
