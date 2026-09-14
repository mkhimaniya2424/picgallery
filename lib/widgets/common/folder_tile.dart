import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/folder_model.dart';
import '../../models/media_model.dart';
import '../media/media_thumb.dart';

/// A single folder row — cover thumbnail (falling back to a gradient
/// folder icon when the folder has no media yet), name, album count,
/// hidden badge — shared by [FolderListScreen] (root-level folders) and
/// [FolderDetailsScreen] (a folder's sub-folders), so both render folders
/// identically instead of keeping two copies of the same tile.
class FolderTile extends StatelessWidget {
  const FolderTile({
    super.key,
    required this.folder,
    required this.onTap,
    this.parentName,
    this.cover,
    this.childFolderCount = 0,
  });

  final FolderModel folder;
  final String? parentName;
  final VoidCallback onTap;

  /// A representative media item from this folder (or its albums), used
  /// as a real cover thumbnail. Null falls back to the gradient icon.
  final MediaModel? cover;

  /// Number of sub-folders nested directly under this one, shown in the
  /// subtitle so folder-in-folder nesting is visible at a glance.
  final int childFolderCount;

  String _subtitle() {
    final parts = <String>['${folder.albumCount} albums'];
    if (childFolderCount > 0) {
      parts.add('$childFolderCount subfolders');
    }
    final base = parts.join(' • ');
    return parentName != null ? '$base • Inside "$parentName"' : base;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceRaised : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: SizedBox(
                width: 48,
                height: 48,
                child: cover != null
                    ? MediaThumb(media: cover!)
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: folder.gradientArgb
                                .map((a) => Color(a))
                                .toList(),
                          ),
                        ),
                        child: const Icon(Icons.folder_rounded,
                            color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder.name,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.textOnDark : AppColors.text),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _subtitle(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.subtitleOnDark : AppColors.subtitle),
                  ),
                ],
              ),
            ),
            if (folder.isHidden)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(Icons.visibility_off_rounded,
                    size: 18, color: isDark ? AppColors.subtitleOnDark : AppColors.subtitle),
              ),
            Icon(Icons.chevron_right_rounded, color: isDark ? AppColors.subtitleOnDark : AppColors.subtitle),
          ],
        ),
      ),
    );
  }
}
