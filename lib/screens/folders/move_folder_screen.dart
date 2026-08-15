import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/folder_model.dart';
import '../../providers/folder_provider.dart';
import '../../widgets/buttons/gradient_button.dart';
import '../../widgets/common/custom_app_bar.dart';

/// Admin-only Move Folder — reached from [FolderDetailsScreen]. Lets the
/// studio owner re-parent a folder under another one, or send it back
/// to the root level.
class MoveFolderScreen extends ConsumerStatefulWidget {
  final String folderId;

  const MoveFolderScreen({super.key, required this.folderId});

  @override
  ConsumerState<MoveFolderScreen> createState() => _MoveFolderScreenState();
}

class _MoveFolderScreenState extends ConsumerState<MoveFolderScreen> {
  String? _selectedParentId;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final folderState = ref.watch(folderProvider);
    final folderController = ref.read(folderProvider);
    final folder = folderState.folderById(widget.folderId);

    if (folder == null) {
      return const Scaffold(
        appBar: CustomAppBar(title: 'Move Folder', showBack: true),
        body: Center(child: Text('Folder not found')),
      );
    }

    if (!_initialized) {
      _selectedParentId = folder.parentId;
      _initialized = true;
    }

    // A folder can't be moved into itself or any of its descendants.
    final descendants = folderController.descendantsOf(folder.id);
    final invalidIds = {folder.id, ...descendants.map((d) => d.id)};

    final candidateParents = folderState.folders
        .where((f) => !invalidIds.contains(f.id))
        .toList();

    String folderPath(FolderModel f) {
      final ancestors = folderController.ancestorsOf(f.id);
      if (ancestors.isEmpty) return f.name;
      return '${ancestors.map((a) => a.name).join(' / ')} / ${f.name}';
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'Move Folder', showBack: true),
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
                          Text(
                            'Moving "${folder.name}"',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          DropdownButtonFormField<String?>(
                            initialValue: _selectedParentId,
                            decoration: const InputDecoration(labelText: 'Move into'),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Root level (no parent)'),
                              ),
                              ...candidateParents.map(
                                (FolderModel f) => DropdownMenuItem<String?>(
                                  value: f.id,
                                  child: Text(folderPath(f)),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() => _selectedParentId = v),
                          ),
                          const Spacer(),
                          const SizedBox(height: AppSpacing.lg),
                          GradientButton(
                            label: 'Move Folder',
                            onPressed: () async {
                              try {
                                await folderController.moveFolder(folder.id, _selectedParentId);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Folder moved successfully'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                Navigator.of(context).maybePop();
                              } catch (e) {
                                if (!context.mounted) return;
                                final msg = e.toString().replaceFirst(RegExp(r'^(Exception|ValidationException):\s*'), '');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(msg),
                                    backgroundColor: AppColors.error,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
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
