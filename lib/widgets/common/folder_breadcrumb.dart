import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../models/folder_model.dart';

/// Renders a "Root / Outer Shoot / Bride"-style breadcrumb for a folder
/// chain (root → ... → current folder), one chip per level.
///
/// [breadcrumb] is the ancestor-to-self chain as returned by
/// [FolderListController.breadcrumbFor] — it does not include a synthetic
/// "Root" entry, so this widget always prepends one itself.
///
/// Pass [onTap] to make the chips navigable (called with `null` for the
/// Root chip, or the tapped folder's id otherwise). Leave it null for a
/// read-only breadcrumb (e.g. a picker preview).
class FolderBreadcrumb extends StatelessWidget {
  const FolderBreadcrumb({
    super.key,
    required this.breadcrumb,
    this.onTap,
    this.rootLabel = 'Root',
  });

  final List<FolderModel> breadcrumb;
  final ValueChanged<String?>? onTap;
  final String rootLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ActionChip(
          label: Text(rootLabel),
          onPressed: onTap == null ? null : () => onTap!(null),
        ),
        for (final folder in breadcrumb) ...[
          const Icon(Icons.chevron_right_rounded, size: 16),
          ActionChip(
            label: Text(folder.name),
            onPressed: onTap == null ? null : () => onTap!(folder.id),
          ),
        ],
      ],
    );
  }
}
