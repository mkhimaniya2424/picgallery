import 'upload_job_model.dart';

/// Represents the complete state of the upload queue.
class UploadQueueState {
  final List<UploadJobModel> jobs;
  final bool isProcessing;

  /// Human-readable last message for UI.
  final String? message;

  // Real-time Metrics
  final double speedBytesPerSecond;
  final Duration? remainingTime;

  const UploadQueueState({
    required this.jobs,
    required this.isProcessing,
    this.message,
    this.speedBytesPerSecond = 0.0,
    this.remainingTime,
  });

  const UploadQueueState.initial()
      : jobs = const [],
        isProcessing = false,
        message = null,
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
    double? speedBytesPerSecond,
    Duration? remainingTime,
    bool clearRemainingTime = false,
  }) {
    return UploadQueueState(
      jobs: jobs ?? this.jobs,
      isProcessing: isProcessing ?? this.isProcessing,
      message: clearMessage ? null : (message ?? this.message),
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
