import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../models/share_link_model.dart';
import '../../providers/album_provider.dart';
import '../../providers/share_link_provider.dart';
import '../../widgets/buttons/gradient_button.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/inputs/custom_text_field.dart';

/// Complete Gallery Settings screen — owns privacy (Public / Private),
/// password protection (ON / OFF + passcode), share URL display & actions
/// (Copy / Share / QR), link expiry (No Expiry vs Custom Date & Time),
/// download permissions (ON / OFF), watermark (ON / OFF), and dangerous
/// actions (Revoke Link / Regenerate Link).
///
/// Share links are REUSABLE by design across multiple visits, devices, and
/// sessions (1st view, 2nd view, 3rd view, next week). Validating passcodes
/// or viewing the gallery NEVER consumes, deletes, or revokes the share token.
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
  bool _passwordEnabled = false;
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
      _passwordEnabled = link.hasPassword;
      _isPublic = !_passwordEnabled;
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
      final timePicked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );
      final hour = timePicked?.hour ?? 23;
      final minute = timePicked?.minute ?? 59;

      setState(() {
        _expiryDate = DateTime(picked.year, picked.month, picked.day, hour, minute, 59);
      });
    }
  }

  bool get _isBackendSynced {
    final id = widget.albumId;
    if (id.length != 36) return false;
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(id);
  }

  Future<void> _saveSettings(GalleryShareLink? existingLink) async {
    final hasExistingPassword =
        existingLink != null && !existingLink.isRevoked && existingLink.hasPassword;

    final requiresPasswordInput = !_isPublic && _passwordEnabled;

    if (requiresPasswordInput && !hasExistingPassword && !_formKey.currentState!.validate()) {
      return;
    }
    if (requiresPasswordInput && hasExistingPassword && _passwordController.text.isNotEmpty) {
      if (!_formKey.currentState!.validate()) return;
    }

    setState(() => _isSaving = true);
    try {
      if (!_isBackendSynced) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This album was created in offline mode and cannot be shared yet. '
              'Please recreate it while connected to sync it to the server.',
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
        password: (requiresPasswordInput && _passwordController.text.isNotEmpty)
            ? _passwordController.text
            : null,
        clearPassword: _isPublic || !_passwordEnabled,
        expiresAt: _hasExpiry ? _expiryDate : null,
        clearExpiry: !_hasExpiry,
        allowDownload: _allowDownload,
        showWatermark: _showWatermark,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gallery settings updated successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't update gallery settings: $e")),
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
          'This will immediately deactivate the current share link. '
          'Clients attempting to access the gallery via this link will receive a "Gallery Access Revoked" error.',
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
        title: 'Gallery Settings',
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
                              // Album Name Banner
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  gradient: AppColors.heroGradient,
                                  borderRadius: BorderRadius.circular(AppRadius.lg),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Target Gallery',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      album.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),

                              if (!_isBackendSynced) ...[
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.cloud_off_rounded, color: Colors.orange, size: 20),
                                      SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Text(
                                          'This album was created offline and hasn\'t been synced to the server. '
                                          'Recreate it while connected to enable sharing.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.orange,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                              ],

                              // A. PRIVACY
                              _buildSectionHeader(context, 'A. PRIVACY'),
                              const SizedBox(height: AppSpacing.xs),
                              _buildPrivacyCard(),
                              const SizedBox(height: AppSpacing.lg),

                              // B. PASSWORD PROTECTION
                              _buildSectionHeader(context, 'B. PASSWORD PROTECTION'),
                              const SizedBox(height: AppSpacing.xs),
                              _buildPasswordCard(hasActiveLink, activeLink),
                              const SizedBox(height: AppSpacing.lg),

                              // C. SHARE LINK (Actions & Preview)
                              if (hasActiveLink) ...[
                                _buildSectionHeader(context, 'C. SHARE LINK'),
                                const SizedBox(height: AppSpacing.xs),
                                _buildShareLinkCard(activeLink),
                                const SizedBox(height: AppSpacing.lg),
                              ],

                              // D & E & F. LINK CONFIGURATION (Expiry, Downloads, Watermark)
                              _buildSectionHeader(context, 'D, E, F. PERMISSIONS & EXPIRY'),
                              const SizedBox(height: AppSpacing.xs),
                              _buildPermissionsCard(),
                              const SizedBox(height: AppSpacing.xl),

                              // Save Button
                              GradientButton(
                                label: hasActiveLink ? 'Save Gallery Settings' : 'Create Share Link',
                                isLoading: _isSaving,
                                onPressed: (_isSaving || !_isBackendSynced)
                                    ? null
                                    : () => _saveSettings(activeLink),
                              ),
                              const SizedBox(height: AppSpacing.xl),

                              // G. REVOKE / DANGER ZONE
                              if (activeLink != null) ...[
                                const Divider(color: AppColors.border),
                                const SizedBox(height: AppSpacing.lg),
                                _buildSectionHeader(context, 'G. REVOKE SHARE LINK & STATUS'),
                                const SizedBox(height: AppSpacing.xs),
                                _buildRevokeAndStatusCard(activeLink),
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
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        color: isDark ? AppColors.textOnDark : AppColors.primary,
      ),
    );
  }

  Widget _buildPrivacyCard() {
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
              'Public',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
            ),
            subtitle: const Text(
              'Accessible to anyone with the share link without entering a passcode.',
              style: TextStyle(fontSize: 12, color: AppColors.subtitle),
            ),
            activeColor: AppColors.primary,
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _isPublic = val;
                  if (_isPublic) _passwordEnabled = false;
                });
              }
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          RadioListTile<bool>(
            value: false,
            groupValue: _isPublic,
            title: const Text(
              'Private',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
            ),
            subtitle: const Text(
              'Accessible only via share link. Reusable link across sessions & devices.',
              style: TextStyle(fontSize: 12, color: AppColors.subtitle),
            ),
            activeColor: AppColors.primary,
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _isPublic = val;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordCard(bool hasActiveLink, GalleryShareLink? activeLink) {
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _passwordEnabled,
            title: const Text(
              'Password Protection',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
            ),
            subtitle: Text(
              _passwordEnabled
                  ? 'ON — Client must enter passcode before viewing gallery.'
                  : 'OFF — Client opens private gallery directly without passcode.',
              style: const TextStyle(fontSize: 12, color: AppColors.subtitle),
            ),
            activeThumbColor: AppColors.primary,
            onChanged: (val) {
              setState(() {
                _passwordEnabled = val;
                if (_passwordEnabled) {
                  _isPublic = false;
                  if (_passwordController.text.isEmpty) {
                    _generateRandomPasscode();
                  }
                } else {
                  _passwordController.clear();
                }
              });
            },
          ),
          if (_passwordEnabled) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CustomTextField(
                    label: (hasActiveLink && activeLink!.hasPassword)
                        ? 'New Passcode (leave blank to keep current)'
                        : 'Passcode',
                    icon: Icons.lock_outline_rounded,
                    controller: _passwordController,
                    obscureText: false,
                    validator: (v) {
                      if (hasActiveLink && activeLink!.hasPassword && (v == null || v.isEmpty)) {
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
          ],
        ],
      ),
    );
  }

  Widget _buildShareLinkCard(GalleryShareLink link) {
    final primaryUrl = link.primaryShareUrl;

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
          const Text(
            'Gallery Share URL',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.subtitle),
          ),
          const SizedBox(height: 4),
          SelectableText(
            primaryUrl,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: primaryUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Share Link copied to clipboard.')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy Link'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () {
                    Share.share(primaryUrl, subject: 'Check out this shared gallery!');
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Expiry
          SwitchListTile(
            value: _hasExpiry,
            title: const Text(
              'Link Expiry',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.text),
            ),
            subtitle: Text(
              _hasExpiry && _expiryDate != null
                  ? 'Expires: ${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year} at ${_expiryDate!.hour.toString().padLeft(2, '0')}:${_expiryDate!.minute.toString().padLeft(2, '0')}'
                  : 'No Expiry (Link remains valid until revoked)',
              style: const TextStyle(fontSize: 11.5, color: AppColors.subtitle),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.subtitle),
                  const SizedBox(width: 8),
                  Text(
                    _expiryDate == null
                        ? 'No date selected'
                        : '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year} ${_expiryDate!.hour.toString().padLeft(2, '0')}:${_expiryDate!.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.text),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _selectExpiryDate(context),
                    child: const Text('Pick Date & Time'),
                  ),
                ],
              ),
            ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          // Download permission
          SwitchListTile(
            value: _allowDownload,
            title: const Text(
              'Allow Downloads',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.text),
            ),
            subtitle: const Text(
              'Clients can download high-resolution photos.',
              style: TextStyle(fontSize: 11.5, color: AppColors.subtitle),
            ),
            activeThumbColor: AppColors.primary,
            onChanged: (val) => setState(() => _allowDownload = val),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          // Watermark
          SwitchListTile(
            value: _showWatermark,
            title: const Text(
              'Watermark',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.text),
            ),
            subtitle: const Text(
              'Display brand watermark overlay over preview media.',
              style: TextStyle(fontSize: 11.5, color: AppColors.subtitle),
            ),
            activeThumbColor: AppColors.primary,
            onChanged: (val) => setState(() => _showWatermark = val),
          ),
        ],
      ),
    );
  }

  Widget _buildRevokeAndStatusCard(GalleryShareLink link) {
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
        border: Border.all(
          color: link.isRevoked ? AppColors.error.withValues(alpha: 0.4) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Share Link Status: ',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.text),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _buildStatChip(Icons.visibility_outlined, '${link.viewsCount} Views'),
              const SizedBox(width: AppSpacing.sm),
              _buildStatChip(Icons.download_outlined, '${link.downloadsCount} Downloads'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!link.isRevoked) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onPressed: _revokeLink,
                icon: const Icon(Icons.link_off_rounded, size: 18),
                label: const Text(
                  'Revoke Link',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Link is revoked. Clients opening this link will see "Gallery Access Revoked".',
                      style: TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  await ref.read(shareLinkControllerProvider(widget.albumId).notifier).createOrUpdate(
                    password: _passwordEnabled ? _passwordController.text : null,
                    clearPassword: !_passwordEnabled,
                    expiresAt: _hasExpiry ? _expiryDate : null,
                    clearExpiry: !_hasExpiry,
                    allowDownload: _allowDownload,
                    showWatermark: _showWatermark,
                  );
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Regenerate Share Link'),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: QrImageView(
                    data: link.primaryShareUrl,
                    version: QrVersions.auto,
                    size: 110.0,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Scan QR Code',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.subtitle),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.subtitle),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.text),
          ),
        ],
      ),
    );
  }
}
