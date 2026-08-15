import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/folder_provider.dart';
import '../../widgets/buttons/gradient_button.dart';
import '../../widgets/common/custom_app_bar.dart';

/// Admin-only Rename Folder — reached from [FolderDetailsScreen].
class RenameFolderScreen extends ConsumerStatefulWidget {
  final String folderId;

  const RenameFolderScreen({super.key, required this.folderId});

  @override
  ConsumerState<RenameFolderScreen> createState() => _RenameFolderScreenState();
}

class _RenameFolderScreenState extends ConsumerState<RenameFolderScreen> {
  final _nameController = TextEditingController();
  bool _initialized = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final folderState = ref.watch(folderProvider);
    final folder = folderState.folderById(widget.folderId);

    if (folder == null) {
      return const Scaffold(
        appBar: CustomAppBar(title: 'Rename Folder', showBack: true),
        body: Center(child: Text('Folder not found')),
      );
    }

    if (!_initialized) {
      _nameController.text = folder.name;
      _initialized = true;
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'Rename Folder', showBack: true),
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
                            Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: 'Folder name'),
                          ),
                          const Spacer(),
                          const SizedBox(height: AppSpacing.lg),
                          GradientButton(
                            label: 'Save Name',
                            onPressed: () async {
                              final name = _nameController.text.trim();
                              if (name.isEmpty) {
                                setState(() => _error = 'Folder name is required');
                                return;
                              }
                              try {
                                await ref.read(folderProvider).renameFolder(folder.id, name);
                                if (!context.mounted) return;
                                setState(() => _error = null);
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(content: Text('Renamed to "$name"')));
                                Navigator.of(context).maybePop();
                              } catch (e) {
                                setState(() => _error = '$e');
                              }
                            },
                          ),
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
