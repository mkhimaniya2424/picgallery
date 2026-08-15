/// Upload state for a single in-flight upload.
///
/// Task 19.9 requirement: expose progress/success/failure driven by
/// the 19.5/19.6 MediaUploadService.
enum UploadStatus {
  idle,
  uploading,
  success,
  failure,
}

class UploadState {
  final UploadStatus status;

  /// Progress across the current file: 0..1.
  final double progress;

  /// Bytes metrics for the current file.
  final int sentBytes;
  final int totalBytes;

  /// Optional error message when [status] is [UploadStatus.failure].
  final String? errorMessage;

  /// Optional metadata returned on success.
  final String? uploadedMediaId;
  final String? uploadedMediaFileName;

  /// Currently uploading job/file identifiers (for UI correlation).
  final String? currentJobId;
  final String? currentFileName;

  const UploadState({
    required this.status,
    required this.progress,
    required this.sentBytes,
    required this.totalBytes,
    this.errorMessage,
    this.uploadedMediaId,
    this.uploadedMediaFileName,
    this.currentJobId,
    this.currentFileName,
  });

  const UploadState.initial()
      : status = UploadStatus.idle,
        progress = 0.0,
        sentBytes = 0,
        totalBytes = 0,
        errorMessage = null,
        uploadedMediaId = null,
        uploadedMediaFileName = null,
        currentJobId = null,
        currentFileName = null;

  UploadState copyWith({
    UploadStatus? status,
    double? progress,
    int? sentBytes,
    int? totalBytes,
    String? errorMessage,
    String? uploadedMediaId,
    String? uploadedMediaFileName,
    String? currentJobId,
    String? currentFileName,
    bool clearError = false,
  }) {
    return UploadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      sentBytes: sentBytes ?? this.sentBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      uploadedMediaId: uploadedMediaId ?? this.uploadedMediaId,
      uploadedMediaFileName: uploadedMediaFileName ?? this.uploadedMediaFileName,
      currentJobId: currentJobId ?? this.currentJobId,
      currentFileName: currentFileName ?? this.currentFileName,
    );
  }
}

