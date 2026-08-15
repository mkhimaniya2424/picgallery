import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin_dashboard_data.dart';

/// Compact horizontal-scroll card for the "Recent Albums" section —
/// folder-style badge + album name + item count, distinct from the
/// larger thumbnail grid used by [RecentUploadCard] for "Recent
/// Uploads" (which also includes standalone video uploads).
class RecentAlbumCard extends StatelessWidget {
  final AlbumUploadData data;
  final VoidCallback? onTap;

  const RecentAlbumCard({super.key, required this.data, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: 132,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
          boxShadow:
              AppShadows.soft(AppColors.primary, opacity: 0.07, blur: 16, y: 8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: data.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.folder_rounded,
                  color: Colors.white, size: 19),
            ),
            const SizedBox(height: 10),
            Text(
              data.albumName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text),
            ),
            const SizedBox(height: 2),
            Text('${data.mediaCount} items',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.subtitle)),
          ],
        ),
      ),
    );
  }
}
