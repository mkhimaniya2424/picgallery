import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../models/folder_model.dart';
import '../../providers/album_provider.dart';
import '../../providers/folder_provider.dart';
import '../../widgets/buttons/gradient_button.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/inputs/custom_text_field.dart';

/// Admin-only Create Album — reached from [AlbumsListScreen]'s FAB, or
/// from [FolderDetailsScreen]'s "Add Album" action with [folderId]
/// pre-filled. Mirrors [CreateFolderScreen]'s validated-form pattern so
/// the two "create" flows feel identical, and hands off to
/// [AlbumListController.createAlbum] — which already validates name
/// uniqueness/length and keeps Folder counts in sync — instead of the
/// old placeholder snackbar.
class CreateAlbumScreen extends ConsumerStatefulWidget {
  /// Optional folder this album should be filed under from the start.
  final String? folderId;

  const CreateAlbumScreen({super.key, this.folderId});

  @override
  ConsumerState<CreateAlbumScreen> createState() => _CreateAlbumScreenState();
}

class _CreateAlbumScreenState extends ConsumerState<CreateAlbumScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  String? _selectedFolderId;
  String? _error;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedFolderId = widget.folderId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final controller = ref.read(albumProvider);
    try {
      final created = await controller.createAlbum(
        name: _nameController.text,
        description: _descController.text,
        folderId: _selectedFolderId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Album "${created.name}" created')),
      );
      // Replace Create Album with Album Details so Back from there
      // returns straight to the Albums List instead of back through
      // this now-stale form.
      Navigator.of(context)
          .pushReplacementNamed(AppRoutes.adminAlbumDetails, arguments: created.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final folderState = ref.watch(folderProvider);
    final folderController = ref.read(folderProvider);
    final foldersLoading = folderState.isLoading;

    String folderPath(FolderModel f) {
      final ancestors = folderController.ancestorsOf(f.id);
      if (ancestors.isEmpty) return f.name;
      return '${ancestors.map((a) => a.name).join(' / ')} / ${f.name}';
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'Create Album', showBack: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: foldersLoading
              ? const Center(child: LoadingWidget(message: 'Loading folders…'))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                            maxWidth: 520,
                          ),
                          child: Form(
                            key: _formKey,
                            child: IntrinsicHeight(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_error != null) ...[
                                    AnimatedSize(
                                      duration: AppDurations.fast,
                                      child: Text(
                                        _error!,
                                        style: const TextStyle(
                                            color: Colors.red, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                  ],
                                  CustomTextField(
                                    label: 'Album name',
                                    icon: Icons.photo_album_rounded,
                                    controller: _nameController,
                                    validator: (v) => (v == null || v.trim().isEmpty)
                                        ? 'Album name is required'
                                        : null,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  CustomTextField(
                                    label: 'Description (optional)',
                                    icon: Icons.notes_rounded,
                                    controller: _descController,
                                    maxLines: 3,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  DropdownButtonFormField<String?>(
                                    value: _selectedFolderId,
                                    decoration: const InputDecoration(
                                      labelText: 'Folder (optional)',
                                      prefixIcon: Icon(Icons.folder_outlined, size: 20),
                                    ),
                                    items: [
                                      const DropdownMenuItem<String?>(
                                          value: null, child: Text('No folder')),
                                      ...folderState.folders.map(
                                        (FolderModel f) => DropdownMenuItem<String?>(
                                          value: f.id,
                                          child: Text(folderPath(f)),
                                        ),
                                      ),
                                    ],
                                    onChanged: (v) => setState(() => _selectedFolderId = v),
                                  ),
                                  const Spacer(),
                                  const SizedBox(height: AppSpacing.lg),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed:
                                              _isSaving ? null : () => Navigator.of(context).maybePop(),
                                          child: const Text('Cancel'),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        flex: 2,
                                        child: GradientButton(
                                          label: 'Create Album',
                                          isLoading: _isSaving,
                                          onPressed: _isSaving ? null : _submit,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}