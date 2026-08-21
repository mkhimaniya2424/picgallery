import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../core/theme/app_theme.dart';
import '../providers/album_provider.dart';
import '../providers/folder_provider.dart';
import 'upload_job_model.dart';
import 'upload_queue_provider.dart';
import 'upload_queue_state.dart';
import 'widgets/upload_queue_tile.dart';

/// The primary Screen for the Studio Upload Module.
///
/// Implements a complete 4-step Upload Wizard:
/// 1. Upload Screen (Selection & Preview)
/// 2. Upload Options (Album/Folder target selection, inline additions, renaming, metadata, WiFi checks)
/// 3. Upload Progress (Individual and overall progress, calculations, speed, network simulation)
/// 4. Upload Complete (Animation, counts, retry failed, destination redirects, upload more)
class UploadQueueScreen extends ConsumerStatefulWidget {
  const UploadQueueScreen({super.key});

  @override
  ConsumerState<UploadQueueScreen> createState() => _UploadQueueScreenState();
}

class _UploadQueueScreenState extends ConsumerState<UploadQueueScreen> {
  final TextEditingController _renameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _renameController.dispose();
    super.dispose();
  }

  String _humanBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var v = bytes.toDouble();
    var i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(v >= 10 || i == 0 ? 0 : 1)} ${units[i]}';
  }

  // ---------------------------------------------------------------------
  // Dialogs for creating Album / Folder inline
  // ---------------------------------------------------------------------
  Future<void> _showCreateAlbumDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Album', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Album Name', hintText: 'e.g. Summer Vacation'),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description (Optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (created == true && nameController.text.trim().isNotEmpty) {
      try {
        final newAlbum = await ref.read(albumProvider).createAlbum(
          name: nameController.text.trim(),
          description: descController.text.trim().isNotEmpty ? descController.text.trim() : null,
        );
        ref.read(uploadQueueProvider.notifier).updateOptions(albumId: newAlbum.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Album "${newAlbum.name}" created successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create album: $e')),
          );
        }
      }
    }
  }

  Future<void> _showCreateFolderDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Folder', style: TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Folder Name', hintText: 'e.g. Clients 2026'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (created == true && nameController.text.trim().isNotEmpty) {
      try {
        final newFolder = await ref.read(folderProvider).createFolder(
          name: nameController.text.trim(),
        );
        ref.read(uploadQueueProvider.notifier).updateOptions(folderId: newFolder.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Folder "${newFolder.name}" created successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create folder: $e')),
          );
        }
      }
    }
  }

  // ---------------------------------------------------------------------
  // Main Step Rendering Functions
  // ---------------------------------------------------------------------

  // STEP 0: SELECT & PREVIEW FILES
  Widget _buildSelectionStep(BuildContext context, UploadQueueState state, UploadQueueController notifier) {
    final files = state.tempPickedFiles;
    final totalSize = files.fold<int>(0, (sum, f) => sum + f.size);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Expanded(
          child: files.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cloud_upload_outlined,
                            size: 64,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Upload Studio Media',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.textOnDark : AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select high-quality images and video files to upload to your Studio Gallery.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: isDark ? AppColors.subtitleOnDark : AppColors.subtitle,
                                height: 1.4,
                              ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              allowMultiple: true,
                              type: FileType.custom,
                              allowedExtensions: const [
                                'jpg', 'jpeg', 'png', 'webp', 'heic',
                                'mp4', 'mov', 'mkv', 'webm', 'avi', 'm4v'
                              ],
                              // Web has no filesystem — `path` isn't just
                              // null there, *accessing the getter itself
                              // throws*. Bytes have to be requested
                              // eagerly so the preview grid below has
                              // something safe to read from.
                              withData: kIsWeb,
                            );
                            if (result != null && result.files.isNotEmpty) {
                              notifier.updatePickedFiles(result.files);
                            }
                          },
                          icon: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white),
                          label: const Text('Browse Files', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      width: double.infinity,
                      color: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Selected ${files.length} file(s)',
                            style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? AppColors.textOnDark : AppColors.text),
                          ),
                          Text(
                            'Total Size: ${_humanBytes(totalSize)}',
                            style: TextStyle(color: isDark ? AppColors.subtitleOnDark : AppColors.subtitle, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: files.length,
                        itemBuilder: (context, idx) {
                          final f = files[idx];
                          final isImage = ['jpg', 'jpeg', 'png', 'webp', 'heic']
                              .contains(f.extension?.toLowerCase());

                          return Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isDark ? AppColors.darkBorder : Colors.black.withOpacity(0.06)),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Center(
                                  // `f.path` isn't just null on web — the
                                  // getter itself throws when touched, so
                                  // `kIsWeb` has to gate access to it
                                  // entirely (a `f.path != null` check
                                  // alone still throws).
                                  child: isImage && kIsWeb && f.bytes != null
                                      ? Image.memory(
                                          f.bytes!,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                        )
                                      : isImage && !kIsWeb && f.path != null
                                          ? Image.file(
                                              File(f.path!),
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                            )
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.play_circle_outline_rounded,
                                              size: 32,
                                              color: Colors.black.withOpacity(0.35),
                                            ),
                                            const SizedBox(height: 4),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                              child: Text(
                                                f.extension?.toUpperCase() ?? 'FILE',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 10,
                                                  color: isDark ? AppColors.subtitleOnDark : Colors.black45,
                                                ),
                                              ),
                                            )
                                          ],
                                        ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: InkWell(
                                  onTap: () => notifier.removePickedFileAt(idx),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
        if (files.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: notifier.clearPickedFiles,
                    child: const Text('Clear All'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => notifier.setWizardStep(1), // Go to options
                    child: const Text('Next: Options'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // STEP 1: OPTIONS & CONFIGURATION
  Widget _buildOptionsStep(BuildContext context, UploadQueueState state, UploadQueueController notifier) {
    final albums = ref.watch(albumProvider).allAlbums;
    final folders = ref.watch(folderProvider).folders;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Target Destination Panel
            Text(
              'Upload Target Destination',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? AppColors.textOnDark : AppColors.text),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: state.selectedAlbumId,
                    decoration: const InputDecoration(labelText: 'Select Album'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('No Album')),
                      ...albums.map((a) => DropdownMenuItem<String?>(value: a.id, child: Text(a.name))),
                    ],
                    onChanged: (val) => notifier.updateOptions(albumId: val, clearAlbum: val == null),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Create New Album',
                  onPressed: () => _showCreateAlbumDialog(context, ref),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: state.selectedFolderId,
                    decoration: const InputDecoration(labelText: 'Select Folder'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('No Folder')),
                      ...folders.map((f) => DropdownMenuItem<String?>(value: f.id, child: Text(f.name))),
                    ],
                    onChanged: (val) => notifier.updateOptions(folderId: val, clearFolder: val == null),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Create New Folder',
                  onPressed: () => _showCreateFolderDialog(context, ref),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),

            const SizedBox(height: 24),
            
            // Renaming Settings
            Text(
              'Batch Renaming Settings',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? AppColors.textOnDark : AppColors.text),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _renameController,
              decoration: const InputDecoration(
                labelText: 'Rename Prefix (Optional)',
                hintText: 'e.g. Wedding_Shoot_ClientA',
              ),
              onChanged: (val) => notifier.updateOptions(
                renamePrefix: val.trim().isNotEmpty ? val.trim() : null,
                clearRenamePrefix: val.trim().isEmpty,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Files will be renamed sequentially: Prefix (1).jpg, Prefix (2).jpg, etc.',
              style: TextStyle(fontSize: 11, color: isDark ? AppColors.subtitleOnDark : AppColors.subtitle, fontWeight: FontWeight.w500),
            ),

            const SizedBox(height: 24),

            // Settings & Compression Panel
            Text(
              'Upload Options',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? AppColors.textOnDark : AppColors.text),
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              title: const Text('Compress Images'),
              subtitle: const Text('Optimizes size before uploading'),
              value: state.compress,
              onChanged: (val) => notifier.updateOptions(compress: val),
            ),
            SwitchListTile(
              title: const Text('Keep Original Quality'),
              subtitle: const Text('Avoid compression artifacts'),
              value: state.keepOriginalQuality,
              onChanged: (val) => notifier.updateOptions(keepOriginalQuality: val),
            ),
            SwitchListTile(
              title: const Text('Upload Original Metadata'),
              subtitle: const Text('Retains EXIF tags, GPS details & creation dates'),
              value: state.uploadMetadata,
              onChanged: (val) => notifier.updateOptions(uploadMetadata: val),
            ),
            SwitchListTile(
              title: const Text('Upload using WiFi only'),
              subtitle: const Text('Pauses uploads on cellular data networks'),
              value: state.wifiOnly,
              onChanged: (val) => notifier.updateOptions(wifiOnly: val),
            ),

            const SizedBox(height: 32),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => notifier.setWizardStep(0),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      await notifier.startUpload();
                    },
                    child: const Text('Start Upload'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // STEP 2: ACTIVE PROGRESS
  Widget _buildProgressStep(BuildContext context, UploadQueueState state, UploadQueueController notifier) {
    final completedCount = state.completedCount;
    final totalCount = state.jobs.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Formatting speed
    String formattedSpeed = '0 KB/s';
    if (state.speedBytesPerSecond > 0) {
      if (state.speedBytesPerSecond >= 1024 * 1024) {
        formattedSpeed = '${(state.speedBytesPerSecond / 1024 / 1024).toStringAsFixed(1)} MB/s';
      } else {
        formattedSpeed = '${(state.speedBytesPerSecond / 1024).toStringAsFixed(0)} KB/s';
      }
    }

    // Formatted remaining time
    String formattedTime = 'estimating...';
    if (state.remainingTime != null) {
      final t = state.remainingTime!;
      if (t.inMinutes > 0) {
        formattedTime = '${t.inMinutes}m ${t.inSeconds % 60}s remaining';
      } else {
        formattedTime = '${t.inSeconds}s remaining';
      }
    }

    return Column(
      children: [
        // Overall progress banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade100)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 4, offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    state.isProcessing ? 'Uploading Studio Media...' : 'Upload Process Paused',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: state.isProcessing ? AppColors.primary : Colors.orange.shade800,
                    ),
                  ),
                  Text(
                    '$completedCount of $totalCount done',
                    style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? AppColors.subtitleOnDark : Colors.black54, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: state.overallProgress,
                  minHeight: 8,
                  backgroundColor: isDark ? AppColors.darkSurfaceRaised : Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    state.isProcessing ? AppColors.primary : Colors.orange.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.speed_rounded, size: 14, color: isDark ? AppColors.subtitleOnDark : Colors.black45),
                      const SizedBox(width: 4),
                      Text(
                        formattedSpeed,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? AppColors.subtitleOnDark : Colors.black54),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 14, color: isDark ? AppColors.subtitleOnDark : Colors.black45),
                      const SizedBox(width: 4),
                      Text(
                        state.isProcessing ? formattedTime : 'Paused',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppColors.subtitleOnDark : Colors.black54),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Control Actions Row
              Row(
                children: [
                  if (state.isProcessing)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: notifier.pauseAll,
                        icon: const Icon(Icons.pause_rounded, size: 16),
                        label: const Text('Pause All'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    )
                  else if (state.jobs.any((j) => j.status == UploadJobStatus.paused))
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: notifier.resumeAll,
                        icon: const Icon(Icons.play_arrow_rounded, size: 16),
                        label: const Text('Resume All'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: notifier.cancelAll,
                      icon: const Icon(Icons.cancel_rounded, size: 16),
                      label: const Text('Cancel All'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade800,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Interactive Network Simulator (Wi-Fi vs Cellular test toggle)
              InkWell(
                onTap: notifier.toggleSimulationNetwork,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.blue.shade900.withOpacity(0.2) : Colors.blue.shade50.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.blue.shade800 : Colors.blue.shade100),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            notifier.simulateCellular ? Icons.signal_cellular_alt_rounded : Icons.wifi_rounded,
                            size: 16,
                            color: isDark ? Colors.blue.shade300 : Colors.blue.shade800,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            notifier.simulateCellular
                                ? "Network Type: Cellular Data"
                                : "Network Type: Wi-Fi",
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "TAP TO SWITCH",
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.blue.shade800,
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // List of files with progress
        Expanded(
          child: state.jobs.isEmpty
              ? const Center(child: Text('No active uploads'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemCount: state.jobs.length,
                  itemBuilder: (context, i) {
                    final job = state.jobs[i];
                    return UploadQueueTile(
                      job: job,
                      onCancel: () => notifier.cancelJob(job.id),
                      onPause: () => notifier.pauseJob(job.id),
                      onResume: () => notifier.resumeJob(job.id),
                      onRetry: () => notifier.retryJob(job.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // STEP 3: UPLOAD COMPLETE
  Widget _buildCompleteStep(BuildContext context, UploadQueueState state, UploadQueueController notifier) {
    final failedCount = state.failedCount;
    final completedCount = state.completedCount;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Premium completion check animation / design
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: failedCount > 0 
                    ? Colors.orange.withOpacity(0.08) 
                    : AppColors.success.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: failedCount > 0 
                      ? Colors.orange.withOpacity(0.3) 
                      : AppColors.success.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 600),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.elasticOut,
                builder: (context, val, child) {
                  return Transform.scale(
                    scale: val,
                    child: Icon(
                      failedCount > 0 ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                      size: 54,
                      color: failedCount > 0 ? Colors.orange.shade800 : AppColors.success,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
              Text(
                failedCount > 0 ? 'Upload Process Finished' : 'Upload Complete!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? AppColors.textOnDark : AppColors.text,
                ),
              ),
            const SizedBox(height: 10),
              Text(
                failedCount > 0
                    ? 'Successfully uploaded $completedCount items, but $failedCount failed.'
                    : 'All $completedCount items have been uploaded to your gallery successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: isDark ? AppColors.subtitleOnDark : Colors.black54, height: 1.4),
              ),
            const SizedBox(height: 36),

            // Metrics Summary Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : Colors.black.withOpacity(0.04)),
                ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '$completedCount',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 4),
                        Text(
                          'Uploaded',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppColors.subtitleOnDark : Colors.black54),
                        ),
                    ],
                  ),
                    Container(width: 1, height: 34, color: isDark ? AppColors.darkBorder : Colors.black.withOpacity(0.08)),
                  Column(
                    children: [
                        Text(
                          '$failedCount',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: failedCount > 0 ? AppColors.error : (isDark ? Colors.white38 : Colors.black38),
                          ),
                        ),
                      const SizedBox(height: 4),
                        Text(
                          'Failed',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppColors.subtitleOnDark : Colors.black54),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Actions panel
            if (failedCount > 0) ...[
              FilledButton.icon(
                onPressed: () async {
                  notifier.setWizardStep(2); // Go to progress
                  await notifier.retryFailed();
                },
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text('Retry Failed Uploads', style: TextStyle(color: Colors.white)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed: () {
                // Return to gallery index
                Navigator.pop(context);
              },
              icon: const Icon(Icons.collections_bookmark_rounded),
              label: const Text('Open Destination Folder'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () async {
                await notifier.resetWizard();
              },
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: const Text('Upload More Files'),
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queueStateAsync = ref.watch(uploadQueueProvider);

    return Scaffold(
      appBar: AppBar(
        title: queueStateAsync.when(
          data: (state) => Text(
            switch (state.wizardStep) {
              0 => 'Select Media',
              1 => 'Upload Options',
              2 => 'Upload Progress',
              _ => 'Upload Finished',
            },
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          error: (_, __) => const Text('Upload Queue'),
          loading: () => const Text('Loading...'),
        ),
        actions: [
          // Cancel queue completely button
          queueStateAsync.when(
            data: (state) {
              if (state.wizardStep == 2 && state.jobs.any((j) => !j.isDone)) {
                return IconButton(
                  tooltip: 'Cancel Entire Queue',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Cancel Uploads?'),
                        content: const Text('Are you sure you want to cancel all active and queued uploads?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, Cancel All')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(uploadQueueProvider.notifier).cancelAll();
                    }
                  },
                );
              }
              return const SizedBox.shrink();
            },
            error: (_, __) => const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: queueStateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 54, color: AppColors.error),
                const SizedBox(height: 12),
                Text('Error loading queue: $e', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        data: (state) {
          return SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: switch (state.wizardStep) {
                0 => _buildSelectionStep(context, state, ref.read(uploadQueueProvider.notifier)),
                1 => _buildOptionsStep(context, state, ref.read(uploadQueueProvider.notifier)),
                2 => _buildProgressStep(context, state, ref.read(uploadQueueProvider.notifier)),
                _ => _buildCompleteStep(context, state, ref.read(uploadQueueProvider.notifier)),
              },
            ),
          );
        },
      ),
    );
  }
}