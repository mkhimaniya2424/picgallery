import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/download_history_provider.dart';
import '../../providers/media_provider.dart';
import '../../models/download_history_model.dart';
import '../../models/media_model.dart' as media_model;
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/delete_confirmation_dialog.dart';
import '../../widgets/common/snackbar_helper.dart';
import '../../widgets/common/anchored_dropdown_field.dart';
import '../../widgets/common/empty_state_card.dart';
import '../../widgets/media/media_thumb.dart';
import '../media/image_viewer_screen.dart';
import '../media/video_player_screen.dart';

class DownloadHistoryScreen extends ConsumerStatefulWidget {
  const DownloadHistoryScreen({super.key});

  @override
  ConsumerState<DownloadHistoryScreen> createState() => _DownloadHistoryScreenState();
}

class _DownloadHistoryScreenState extends ConsumerState<DownloadHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // The provider only auto-loads once, the first time it's created
    // (app start). Without this, reopening the screen after a fresh
    // download still shows whatever was cached back then until the
    // user manually pulls to refresh.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(downloadHistoryProvider).refresh();
    });
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    final value =
        size >= 10 ? size.toStringAsFixed(0) : size.toStringAsFixed(1);
    return '$value ${units[unitIndex]}';
  }

  String _formatDateTime(DateTime dt) {
    // Compact and locale-friendly.
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  // Standardized confirmation dialog helper is now imported from delete_confirmation_dialog.dart

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(downloadHistoryProvider);
    // Needed so each row can resolve its `mediaId` to a real MediaModel
    // (for a proper thumbnail and to open the in-app viewer) the same
    // way ImageViewerScreen/VideoPlayerScreen already do — matching by
    // id against whatever's currently loaded, rather than a fresh
    // per-row network call.
    final mediaList = ref.watch(mediaProvider).allMedia;

    media_model.MediaModel? findMedia(String? mediaId) {
      if (mediaId == null || mediaId.isEmpty) return null;
      for (final m in mediaList) {
        if (m.id == mediaId) return m;
      }
      return null;
    }

    void openItem(DownloadHistoryModel item) {
      final media = findMedia(item.mediaId);
      if (media == null) {
        SnackBarHelper.showError(
          context,
          'This media is no longer available.',
        );
        return;
      }
      if (media.type == media_model.MediaType.video) {
        Navigator.of(context).pushNamed(
          AppRoutes.videoPlayer,
          arguments: VideoPlayerArgs(
            mediaId: media.id,
            mediaIds: [media.id],
            initialIndex: 0,
          ),
        );
      } else {
        Navigator.of(context).pushNamed(
          AppRoutes.imageViewer,
          arguments: ImageViewerArgs(
            mediaIds: [media.id],
            initialIndex: 0,
          ),
        );
      }
    }

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: controller.refresh,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: CustomAppBar(
                  title: 'Download History',
                  showBack: true,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  children: [
                    TextField(
                      onChanged: controller.setSearchQuery,
                      controller: TextEditingController.fromValue(
                        TextEditingValue(text: controller.searchQuery),
                      ),
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded),
                          labelText: 'Search downloads',
                          hintText: 'Type a file name...'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _FilterChips(
                      selected: controller.filter,
                      onSelected: controller.setFilter,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SortRow(
                      value: controller.sort,
                      onChanged: controller.setSort,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              sliver: controller.filteredSorted.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: EmptyStateCard(
                          icon: Icons.download_rounded,
                          message: controller.isLoading
                              ? 'Loading history...'
                              : 'No downloads yet.',
                        ),
                      ),
                    )
                  : SliverList.separated(
                      itemCount: controller.filteredSorted.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, thickness: 0.5),
                      itemBuilder: (context, index) {
                        final item = controller.filteredSorted[index];
                        final badgeColor = item.mediaType == MediaType.photo
                            ? AppColors.secondary
                            : AppColors.accent;
                        final badgeText = item.mediaType == MediaType.photo
                            ? 'Photo'
                            : 'Video';

                        final resolvedMedia = findMedia(item.mediaId);

                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => openItem(item),
                          child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Thumb(
                                thumbnailPath: item.thumbnailPath,
                                networkThumbnailUrl: item.thumbnailUrl ?? item.fileUrl,
                                media: resolvedMedia,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.fileName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.sm,
                                            vertical: AppSpacing.xs,
                                          ),
                                          decoration: BoxDecoration(
                                            color: badgeColor.withValues(
                                                alpha: 0.15),
                                            border:
                                                Border.all(color: badgeColor),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            badgeText,
                                            style: TextStyle(
                                              color: badgeColor,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${_formatBytes(item.size)} • ${_formatDateTime(item.downloadedAt)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded),
                                color: AppColors.error,
                                onPressed: () async {
                                  final confirmed = await showDeleteConfirmationDialog(
                                    context: context,
                                    title: 'Delete item?',
                                    message: 'Remove "${item.fileName}" from your download history? This cannot be undone.',
                                  );
                                  if (!context.mounted) return;
                                  if (confirmed) {
                                    await controller.deleteOne(item.id);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).clearSnackBars();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Item deleted'),
                                        backgroundColor: AppColors.success,
                                        behavior: SnackBarBehavior.floating,
                                        action: SnackBarAction(
                                          label: 'Undo',
                                          textColor: Colors.white,
                                          onPressed: () async {
                                            await controller.undo();
                                          },
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                          ),
                        );
                      },
                    ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xxxl,
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: controller.items.isEmpty
                        ? null
                        : () async {
                            final confirmed = await showDeleteConfirmationDialog(
                              context: context,
                              title: 'Delete item?',
                              message: 'This will remove all download history items. You can undo right away.',
                              confirmText: 'Clear All',
                            );
                            if (!context.mounted) return;
                            if (confirmed) {
                              await controller.clearAll();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('History cleared'),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                  action: SnackBarAction(
                                    label: 'Undo',
                                    textColor: Colors.white,
                                    onPressed: () async => controller.undo(),
                                  ),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.delete_sweep_rounded),
                    label: const Text('Clear History'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String thumbnailPath;
  final String? networkThumbnailUrl;
  final media_model.MediaModel? media;
  const _Thumb({required this.thumbnailPath, this.networkThumbnailUrl, this.media});

  @override
  Widget build(BuildContext context) {
    const size = 58.0;
    final hasLocalThumb = thumbnailPath.trim().isNotEmpty;
    final networkUrl = networkThumbnailUrl?.trim();
    final hasNetworkThumb = networkUrl != null && networkUrl.isNotEmpty;

    Widget child;
    if (hasLocalThumb) {
      // Local-session download: file may not exist anymore; UI should
      // still not crash. If it does, Image.file works; if not, it
      // falls back below.
      child = Image.file(
        File(thumbnailPath),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => media != null
            ? MediaThumb(media: media!)
            : (hasNetworkThumb ? _NetworkThumb(url: networkUrl) : _Placeholder()),
      );
    } else if (media != null) {
      // Resolved against the current account's own media list — the
      // best option when it's available since it also carries edit
      // state, but for a client account this is almost never
      // populated (a client's media list never contains another
      // studio's media), which is what the server-resolved URL below
      // is for.
      child = MediaThumb(media: media!);
    } else if (hasNetworkThumb) {
      // API-sourced row with no local media match — use the
      // server-resolved thumbnail/file URL from `DownloadEventRead`
      // directly rather than falling back to a placeholder.
      child = _NetworkThumb(url: networkUrl);
    } else {
      child = _Placeholder();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: child,
    );
  }
}

class _NetworkThumb extends StatelessWidget {
  final String url;
  const _NetworkThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _Placeholder(),
    );
  }
}

class _Placeholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.image_not_supported_rounded,
        color: AppColors.subtitle,
        size: 26,
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final DownloadHistoryFilter selected;
  final ValueChanged<DownloadHistoryFilter> onSelected;

  const _FilterChips({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Chip(
          label: 'All',
          selected: selected == DownloadHistoryFilter.all,
          onTap: () => onSelected(DownloadHistoryFilter.all),
        ),
        const SizedBox(width: 10),
        _Chip(
          label: 'Photos',
          selected: selected == DownloadHistoryFilter.photos,
          onTap: () => onSelected(DownloadHistoryFilter.photos),
        ),
        const SizedBox(width: 10),
        _Chip(
          label: 'Videos',
          selected: selected == DownloadHistoryFilter.videos,
          onTap: () => onSelected(DownloadHistoryFilter.videos),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg =
        selected ? AppColors.primary.withValues(alpha: 0.14) : Colors.white;
    final border = selected ? AppColors.primary : AppColors.border;
    final fg = selected ? AppColors.primary : AppColors.subtitle;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _SortRow extends StatelessWidget {
  final DownloadHistorySort value;
  final ValueChanged<DownloadHistorySort> onChanged;

  const _SortRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Sort:',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AnchoredDropdownField<DownloadHistorySort>(
            value: value,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(
                value: DownloadHistorySort.recent,
                child: Text('Recent'),
              ),
              const DropdownMenuItem(
                value: DownloadHistorySort.name,
                child: Text('Name'),
              ),
              const DropdownMenuItem(
                value: DownloadHistorySort.size,
                child: Text('Size'),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}