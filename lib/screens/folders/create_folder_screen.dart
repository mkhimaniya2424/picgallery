import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../models/folder_model.dart';
import '../../providers/folder_provider.dart';
import '../../widgets/buttons/gradient_button.dart';
import '../../widgets/common/custom_app_bar.dart';

/// Admin-only Create Folder — reached from [FolderListScreen]'s FAB.
/// Optionally nests the new folder under an existing one (feeds Move
/// Folder's same parent concept).
class CreateFolderScreen extends ConsumerStatefulWidget {
  /// Optional pre-selected parent, e.g. when creating a folder from
  /// inside another folder's details in a future flow.
  final String? parentId;

  const CreateFolderScreen({super.key, this.parentId});

  @override
  ConsumerState<CreateFolderScreen> createState() => _CreateFolderScreenState();
}

class _CreateFolderScreenState extends ConsumerState<CreateFolderScreen> {
  final _nameController = TextEditingController();
  String? _parentId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _parentId = widget.parentId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Folder name is required');
      return;
    }

    final controller = ref.read(folderProvider);
    try {
      await controller.createFolder(name: name, parentId: _parentId);
      if (!mounted) return;
      setState(() => _error = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Folder "$name" created')),
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final folderState = ref.watch(folderProvider);
    final folderController = ref.read(folderProvider);

    String folderPath(FolderModel f) {
      final ancestors = folderController.ancestorsOf(f.id);
      if (ancestors.isEmpty) return f.name;
      return '${ancestors.map((a) => a.name).join(' / ')} / ${f.name}';
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'Create Folder', showBack: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight, maxWidth: 520),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_error != null) ...[
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: 'Folder name'),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          DropdownButtonFormField<String?>(
                            initialValue: _parentId,
                            decoration: const InputDecoration(labelText: 'Parent folder (optional)'),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('No parent — root level'),
                              ),
                              ...folderState.folders.map(
                                (FolderModel f) => DropdownMenuItem<String?>(
                                  value: f.id,
                                  child: Text(folderPath(f)),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() => _parentId = v),
                          ),
                          const Spacer(),
                          const SizedBox(height: AppSpacing.lg),
                          GradientButton(label: 'Create Folder', onPressed: _submit),
                        ],
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
