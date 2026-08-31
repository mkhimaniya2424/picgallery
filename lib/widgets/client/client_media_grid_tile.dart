import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/media_model.dart';
import '../../providers/auth_providers.dart' show apiClientProvider;
import '../../services/download_service.dart';
import '../../services/download_service_impl.dart';
import '../../services/media_file_cache.dart';
import '../../services/permission_service.dart';
import '../../screens/client/client_media_detail_screen.dart';

/// Client-facing media grid tile with download and view options.
///
/// Shows:
/// - Thumbnail with play icon for videos
/// - Overlay action buttons (download, view, like)
/// - Permission-gated download experience matching real-life apps
///
/// Unlike studio-owner tiles, this:
/// - No delete (client can't manage shared galleries)
/// - No favorite (clients use "like" instead)
/// - No edit option
/// - Download requires permission check before attempting save
class ClientMediaGridTile extends ConsumerStatefulWidget {
  final MediaModel media;
  final String studioId;
  final String albumId;
  final String? heroTag;

  /// Callback when download completes successfully.
  /// Useful for refreshing Download History or showing a toast.
  final VoidCallback? onDownloadComplete;

  const ClientMediaGridTile({
    super.key,
    required this.media,
    required this.studioId,
    required this.albumId,
    this.heroTag,
    this.onDownloadComplete,
  });

  @override
  ConsumerState<ClientMediaGridTile> createState() =>
      _ClientMediaGridTileState();
}

class _ClientMediaGridTileState extends ConsumerState<ClientMediaGridTile> {
  static const DownloadService _downloadService = DownloadServiceImpl();
  static const MediaFileCache _fileCache = MediaFileCache();

  bool _isDownloading = false;

  Future<bool> _checkStoragePermission() async {
    final granted =
        await PermissionService.instance.checkAndRequestStoragePermission();

    if (!granted && mounted) {
      final isPermanent = await PermissionService.instance
          .isPermanentlyDenied(Permission.photos);

      if (isPermanent && mounted) {
        _showPermissionDeniedDialog();
      }
    }

    return granted;
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Storage Permission Denied'),
        content: const Text(
          'Enable storage access in Settings to download media.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              PermissionService.instance.openAppSettingsPage();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadMedia() async {
    if (!await _checkStoragePermission()) return;

    setState(() => _isDownloading = true);

    try {
      bool saved = false;
      final media = widget.media;
      final apiClient = ref.read(apiClientProvider);

      if (kIsWeb) {
        final result = await _fileCache.bytesFor(media);
        if (result == null) return;
        if (!mounted) return;
        saved = await _downloadService.downloadBytes(
          context: context,
          bytes: result.bytes,
          fileName: result.fileName,
          mediaId: media.id,
          apiClient: apiClient,
          isClientUser: true,
        );
      } else {
        final localPath = await _fileCache.localPathFor(media);
        if (localPath == null) return;
        if (!mounted) return;
        saved = await _downloadService.downloadOriginal(
          context: context,
          filePath: localPath,
          mediaId: media.id,
          apiClient: apiClient,
          isClientUser: true,
        );
      }

      if (saved) {
        widget.onDownloadComplete?.call();
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  void _openDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientMediaDetailScreen(
          mediaId: widget.media.id,
          media: widget.media,
          heroTag: widget.heroTag,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    final isVideo = media.type == MediaType.video;

    return GestureDetector(
      onTap: _openDetail,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail
            Hero(
              tag: widget.heroTag ?? media.id,
              child: Image.network(
                media.displayThumbnailPath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey[300],
                  child: const Icon(
                    Icons.broken_image,
                    size: 48,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),

            // Scrim for buttons
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha(120),
                    ],
                  ),
                ),
              ),
            ),

            // Video play icon
            if (isVideo)
              Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(230),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.black,
                    size: 28,
                  ),
                ),
              ),

            // Action buttons (bottom right)
            Positioned(
              bottom: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Download button
                  _ActionButton(
                    icon: _isDownloading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withAlpha(220),
                              ),
                            ),
                          )
                        : const Icon(Icons.download, size: 18),
                    onPressed: _isDownloading ? null : _downloadMedia,
                    tooltip: 'Download',
                  ),
                  const SizedBox(width: 4),
                  // View button
                  _ActionButton(
                    icon: const Icon(Icons.fullscreen, size: 18),
                    onPressed: _openDetail,
                    tooltip: 'View',
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

/// Small circular icon button for media grid overlay.
class _ActionButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  const _ActionButton({
    required this.icon,
    this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(140),
          shape: BoxShape.circle,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            child: Center(
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.white),
                child: IconTheme(
                  data: const IconThemeData(color: Colors.white),
                  child: icon,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}