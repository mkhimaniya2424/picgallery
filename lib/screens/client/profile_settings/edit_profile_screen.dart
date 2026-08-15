import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/settings_provider.dart';
import '../../../widgets/common/custom_app_bar.dart';
import '../../../widgets/inputs/custom_text_field.dart';
import '../../../services/media_picker_service.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  Uint8List? _avatarBytes;

  Future<void> _pickAvatar() async {
    final picker = MediaPickerService();
    final files = await picker.pickPhotos(allowMultiple: false);
    if (files.isNotEmpty) {
      setState(() {
        _avatarBytes = Uint8List.fromList(files.first.bytes);
      });
    }
  }

  @override
  void initState() {
    super.initState();

    final settings = ref.read(settingsProvider);
    _nameController = TextEditingController(text: settings.photographerName);
    _emailController = TextEditingController(text: settings.email);
    // Phone number is not present in SettingsModel right now.
    // Keep it as a local-only field until backend integration.
    _phoneController = TextEditingController(text: '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Edit Profile',
        showBack: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _ProfilePhotoTile(
              avatarBytes: _avatarBytes,
              onEdit: _pickAvatar,
            ),
            const SizedBox(height: AppSpacing.lg),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  CustomTextField(
                    label: 'Name',
                    icon: Icons.person_outline_rounded,
                    controller: _nameController,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Name is required';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CustomTextField(
                    label: 'Email',
                    icon: Icons.email_outlined,
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Email is required';
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CustomTextField(
                    label: 'Phone Number',
                    icon: Icons.phone_outlined,
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton.icon(
                    icon: const Icon(Icons.save_rounded),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: () async {
                      final ok = _formKey.currentState?.validate() ?? false;
                      if (!ok) return;

                      // Persist only what SettingsModel supports for now.
                      await ref.read(settingsProvider.notifier).updateSettings(
                            settings.copyWith(
                              photographerName: _nameController.text.trim(),
                              email: _emailController.text.trim(),
                            ),
                          );

                      if (!mounted) return;
                      Navigator.of(context).pop();
                    },
                    label: const Text('Save Changes'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePhotoTile extends StatelessWidget {
  final Uint8List? avatarBytes;
  final VoidCallback onEdit;

  const _ProfilePhotoTile({this.avatarBytes, required this.onEdit});

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
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: avatarBytes == null ? AppColors.heroGradient : null,
              image: avatarBytes != null
                  ? DecorationImage(
                      image: MemoryImage(avatarBytes!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: avatarBytes == null
                ? const Icon(Icons.person_rounded, color: Colors.white, size: 28)
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Profile Photo',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  avatarBytes != null ? 'Photo selected' : 'No photo uploaded',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          )
        ],
      ),
    );
  }
}
