import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
  bool _hasExpiry = false;
  DateTime? _expiryDate;
  bool _allowDownload = true;
  bool _showWatermark = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _initFields(WidgetRef ref) {
    if (_initialized) return;
    _initialized = true;

    final link = ref.read(shareLinkProvider).getLinkForAlbum(widget.albumId);
    if (link != null && !link.revoked) {
      _isPublic = link.isPublic;
      _passwordController.text = link.password ?? '';
      _hasExpiry = link.expiryDate != null;
      _expiryDate = link.expiryDate;
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

  Future<void> _saveSettings() async {
    if (!_isPublic && !_formKey.currentState!.validate()) {
      return;
    }

    final notifier = ref.read(shareLinkProvider.notifier);
    await notifier.createOrUpdateLink(
      albumId: widget.albumId,
      isPublic: _isPublic,
      password: _isPublic ? null : _passwordController.text,
      expiryDate: _hasExpiry ? _expiryDate : null,
      allowDownload: _allowDownload,
      showWatermark: _showWatermark,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share settings updated successfully.')),
    );
  }

  Future<void> _revokeLink(String linkId) async {
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

    final notifier = ref.read(shareLinkProvider.notifier);
    await notifier.revokeLink(linkId);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share link revoked.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    _initFields(ref);
    final albums = ref.watch(albumProvider).allAlbums;
    final album = albums.firstWhere((a) => a.id == widget.albumId);

    final linkState = ref.watch(shareLinkProvider);
    final activeLink = linkState.getLinkForAlbum(widget.albumId);
    final hasActiveLink = activeLink != null && !activeLink.revoked;

    // Simulated share link URL
    final shareUrl = hasActiveLink
        ? 'https://picgallery.com/shared/gallery/${activeLink.id}'
        : '';

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Share "${album.name}"',
        showBack: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
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
                        _buildSectionHeader('Gallery Type'),
                        const SizedBox(height: AppSpacing.sm),
                        _buildGalleryTypeSelector(),
                        const SizedBox(height: AppSpacing.lg),
                        if (!_isPublic) ...[
                          _buildSectionHeader('Security Settings'),
                          const SizedBox(height: AppSpacing.sm),
                          CustomTextField(
                            label: 'Access Password',
                            icon: Icons.lock_outline_rounded,
                            controller: _passwordController,
                            obscureText: true,
                            validator: (v) {
                              if (v == null || v.trim().length < 4) {
                                return 'Password must be at least 4 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        _buildSectionHeader('Link Configuration'),
                        const SizedBox(height: AppSpacing.sm),
                        _buildLinkSettingsCard(),
                        const SizedBox(height: AppSpacing.xl),
                        GradientButton(
                          label: hasActiveLink ? 'Update Settings' : 'Generate Share Link',
                          onPressed: _saveSettings,
                        ),
                        if (hasActiveLink) ...[
                          const SizedBox(height: AppSpacing.xxl),
                          const Divider(color: AppColors.border),
                          const SizedBox(height: AppSpacing.lg),
                          _buildSectionHeader('Active Share Link'),
                          const SizedBox(height: AppSpacing.sm),
                          _buildActiveLinkCard(activeLink, shareUrl),
                          const SizedBox(height: AppSpacing.xl),
                          _buildSectionHeader('Link Analytics & QR'),
                          const SizedBox(height: AppSpacing.sm),
                          _buildAnalyticsAndQrCard(activeLink, shareUrl),
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

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w800,
        color: AppColors.text,
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
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: const Text(
              'Anyone with the link can view and browse the photos.',
              style: TextStyle(fontSize: 12),
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
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: const Text(
              'Requires entering a passcode to validate access.',
              style: TextStyle(fontSize: 12),
            ),
            activeColor: AppColors.primary,
            onChanged: (val) {
              if (val != null) setState(() => _isPublic = val);
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
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
            subtitle: const Text(
              'Link will automatically expire after the date.',
              style: TextStyle(fontSize: 11.5),
            ),
            activeColor: AppColors.primary,
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
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
            subtitle: const Text(
              'Clients can download high-res original photos.',
              style: TextStyle(fontSize: 11.5),
            ),
            activeColor: AppColors.primary,
            onChanged: (val) => setState(() => _allowDownload = val),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          SwitchListTile(
            value: _showWatermark,
            title: const Text(
              'Overlay Watermark',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
            subtitle: const Text(
              'Display a soft "picgallery" brand watermarking over photos.',
              style: TextStyle(fontSize: 11.5),
            ),
            activeColor: AppColors.primary,
            onChanged: (val) => setState(() => _showWatermark = val),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveLinkCard(GalleryShareLink link, String shareUrl) {
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
                  shareUrl,
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
                  Clipboard.setData(ClipboardData(text: shareUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Share URL copied to clipboard.')),
                  );
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
                      arguments: {'linkId': link.id},
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
                  onPressed: () => _revokeLink(link.id),
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

  Widget _buildAnalyticsAndQrCard(GalleryShareLink link, String shareUrl) {
    final statusColor = link.isExpired
        ? Colors.orange
        : (link.revoked ? AppColors.error : AppColors.success);
    final statusText = link.isExpired
        ? 'Expired'
        : (link.revoked ? 'Revoked' : 'Active');

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
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
                const SizedBox(height: AppSpacing.md),
                _buildAnalyticRow(Icons.info_outline_rounded, 'Status', statusText, valueColor: statusColor),
                _buildAnalyticRow(Icons.visibility_outlined, 'Total Views', '${link.viewsCount}'),
                _buildAnalyticRow(Icons.download_outlined, 'Downloads', '${link.downloadsCount}'),
                _buildAnalyticRow(Icons.lock_clock_outlined, 'Type', link.isPublic ? 'Public' : 'Private (Protected)'),
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
                  data: shareUrl,
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
