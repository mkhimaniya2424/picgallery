import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin_dashboard_data.dart';

/// A single grid card for the Recent Uploads section: the group's real
/// thumbnail (when the backend has produced one) over a gradient + icon
/// placeholder that shows through while it loads or if it's missing/fails,
/// a media-count badge, the album name, and how long ago it was uploaded.
class RecentUploadCard extends StatelessWidget {
  final AlbumUploadData data;

  const RecentUploadCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow:
            AppShadows.soft(AppColors.primary, opacity: 0.07, blur: 18, y: 9),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.35,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Gradient + icon placeholder — always present underneath,
                // so it shows through while the thumbnail loads and stays
                // as the fallback if there's no thumbnail or it fails.
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: data.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                  ),
                  child: Center(
                    child: Icon(data.icon,
                        color: Colors.white.withValues(alpha: 0.85), size: 34),
                  ),
                ),
                if (data.thumbnailUrl != null && data.thumbnailUrl!.isNotEmpty)
                  Image.network(
                    data.thumbnailUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      // Keep the gradient/icon visible underneath while
                      // the image streams in instead of a spinner.
                      return const SizedBox.shrink();
                    },
                    errorBuilder: (context, error, stackTrace) {
                      // Thumbnail failed (broken URL, no network, etc.) —
                      // gradient + icon underneath already covers this.
                      return const SizedBox.shrink();
                    },
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.32),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                            data.isVideo
                                ? Icons.videocam_rounded
                                : Icons.photo_rounded,
                            size: 11,
                            color: Colors.white),
                        const SizedBox(width: 4),
                        Text('${data.mediaCount}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data.albumName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data.uploadedAgo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.subtitle),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}