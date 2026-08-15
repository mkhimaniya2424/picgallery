import 'package:file_picker/file_picker.dart';
import 'upload_job_model.dart';

/// Represents the complete state of the upload queue and the wizard flow.
class UploadQueueState {
  final List<UploadJobModel> jobs;
  final bool isProcessing;

  /// Human-readable last message for UI.
  final String? message;

  // Wizard Flow state
  /// 0 = Selection, 1 = Options, 2 = Progress, 3 = Complete
  final int wizardStep;
  final List<PlatformFile> tempPickedFiles;

  // Selected options for the current batch
  final String? selectedAlbumId;
  final String? selectedFolderId;
  final String? renamePrefix;
  final bool compress;
  final bool wifiOnly;
  final bool keepOriginalQuality;
  final bool uploadMetadata;

  // Real-time Metrics
  final double speedBytesPerSecond;
  final Duration? remainingTime;

  const UploadQueueState({
    required this.jobs,
    required this.isProcessing,
    this.message,
    this.wizardStep = 0,
    this.tempPickedFiles = const [],
    this.selectedAlbumId,
    this.selectedFolderId,
    this.renamePrefix,
    this.compress = false,
    this.wifiOnly = false,
    this.keepOriginalQuality = true,
    this.uploadMetadata = true,
    this.speedBytesPerSecond = 0.0,
    this.remainingTime,
  });

  const UploadQueueState.initial()
      : jobs = const [],
        isProcessing = false,
        message = null,
        wizardStep = 0,
        tempPickedFiles = const [],
        selectedAlbumId = null,
        selectedFolderId = null,
        renamePrefix = null,
        compress = false,
        wifiOnly = false,
        keepOriginalQuality = true,
        uploadMetadata = true,
        speedBytesPerSecond = 0.0,
        remainingTime = null;

  int get queuedCount =>
      jobs.where((j) => j.status == UploadJobStatus.queued).length;
  int get uploadingCount =>
      jobs.where((j) => j.status == UploadJobStatus.uploading).length;
  int get completedCount =>
      jobs.where((j) => j.status == UploadJobStatus.completed).length;
  int get failedCount =>
      jobs.where((j) => j.status == UploadJobStatus.failed).length;
  int get pausedCount =>
      jobs.where((j) => j.status == UploadJobStatus.paused).length;

  int get activeBatchCount => jobs
      .where((j) =>
          j.status == UploadJobStatus.uploading ||
          j.status == UploadJobStatus.queued ||
          j.status == UploadJobStatus.paused)
      .length;

  double get overallProgress {
    final activeJobs = jobs
        .where((j) => !j.isDone || j.status == UploadJobStatus.completed)
        .toList();
    if (activeJobs.isEmpty) return 0.0;

    int totalBytes = 0;
    int uploadedBytes = 0;
    for (final j in activeJobs) {
      totalBytes += j.totalBytes;
      uploadedBytes += j.uploadedBytes;
    }

    if (totalBytes <= 0) return 0.0;
    return (uploadedBytes / totalBytes).clamp(0.0, 1.0);
  }

  UploadQueueState copyWith({
    List<UploadJobModel>? jobs,
    bool? isProcessing,
    String? message,
    bool clearMessage = false,
    int? wizardStep,
    List<PlatformFile>? tempPickedFiles,
    String? selectedAlbumId,
    bool clearAlbum = false,
    String? selectedFolderId,
    bool clearFolder = false,
    String? renamePrefix,
    bool clearRenamePrefix = false,
    bool? compress,
    bool? wifiOnly,
    bool? keepOriginalQuality,
    bool? uploadMetadata,
    double? speedBytesPerSecond,
    Duration? remainingTime,
    bool clearRemainingTime = false,
  }) {
    return UploadQueueState(
      jobs: jobs ?? this.jobs,
      isProcessing: isProcessing ?? this.isProcessing,
      message: clearMessage ? null : (message ?? this.message),
      wizardStep: wizardStep ?? this.wizardStep,
      tempPickedFiles: tempPickedFiles ?? this.tempPickedFiles,
      selectedAlbumId:
          clearAlbum ? null : (selectedAlbumId ?? this.selectedAlbumId),
      selectedFolderId:
          clearFolder ? null : (selectedFolderId ?? this.selectedFolderId),
      renamePrefix:
          clearRenamePrefix ? null : (renamePrefix ?? this.renamePrefix),
      compress: compress ?? this.compress,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      keepOriginalQuality: keepOriginalQuality ?? this.keepOriginalQuality,
      uploadMetadata: uploadMetadata ?? this.uploadMetadata,
      speedBytesPerSecond: speedBytesPerSecond ?? this.speedBytesPerSecond,
      remainingTime:
          clearRemainingTime ? null : (remainingTime ?? this.remainingTime),
    );
  }

  UploadJobModel? jobById(String id) {
    try {
      return jobs.firstWhere((j) => j.id == id);
    } catch (_) {
      return null;
    }
  }
}
