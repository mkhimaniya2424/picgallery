import 'dart:typed_data';

/// Represents a single upload task in the queue.
///
/// Features:
/// - Supports paused state
/// - Stores file path and options for production-ready upload simulation/checks
/// - JSON serialization for Hive persistence
enum UploadJobStatus {
  queued,
  uploading,
  completed,
  failed,
  canceled,
  paused,
}

class UploadJobModel {
  final String id;
  final String fileName;

  /// Empty on web — there's no real filesystem path there, and even
  /// `PlatformFile.path` throws (not just null) if touched. Mobile/desktop
  /// use this to re-read the file's bytes when the real upload starts.
  final String filePath;

  /// Web's substitute for [filePath]: the file's bytes captured once, at
  /// pick time, since a browser gives no way to re-read a file from a
  /// path later. Not persisted (see [toJson]) — a page reload invalidates
  /// them anyway, same as it would any blob URL, so a job still `queued`/
  /// `paused` across a reload needs the user to re-pick it.
  final Uint8List? webBytes;

  /// Intended target album/folder.
  final String? albumId;
  final String? folderId;

  /// Bytes total/loaded.
  final int totalBytes;
  final int uploadedBytes;

  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  final UploadJobStatus status;

  /// Optional error message when failed.
  final String? errorMessage;

  // Options fields
  final bool compress;
  final bool wifiOnly;
  final bool keepOriginalQuality;
  final bool uploadMetadata;

  /// Task 19.12 — offline-upload queueing.
  ///
  /// True when this job's most recent failure looked like a connectivity
  /// problem (the request never reached the server) rather than a real
  /// server-side rejection (bad file type, 413 too large, 401, etc). Jobs
  /// in this state are picked back up automatically once connectivity
  /// looks like it's returned — see `UploadQueueController._tickOfflineRetries`
  /// — instead of sitting there requiring the user to tap Retry.
  final bool offlinePending;

  /// Consecutive connectivity-caused failures for this job, used to back
  /// off the automatic retry interval (so a genuinely offline device isn't
  /// hammered every few seconds).
  final int offlineRetryCount;

  /// Earliest time the offline-retry loop is allowed to requeue this job
  /// again. Null means it's eligible right away.
  final DateTime? nextRetryAt;

  const UploadJobModel({
    required this.id,
    required this.fileName,
    required this.filePath,
    this.webBytes,
    this.albumId,
    this.folderId,
    required this.totalBytes,
    required this.uploadedBytes,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
    required this.status,
    this.errorMessage,
    this.compress = false,
    this.wifiOnly = false,
    this.keepOriginalQuality = true,
    this.uploadMetadata = true,
    this.offlinePending = false,
    this.offlineRetryCount = 0,
    this.nextRetryAt,
  });

  double get progress {
    if (totalBytes <= 0) return 0;
    return (uploadedBytes / totalBytes).clamp(0.0, 1.0);
  }

  bool get isDone =>
      status == UploadJobStatus.completed ||
      status == UploadJobStatus.failed ||
      status == UploadJobStatus.canceled;

  UploadJobModel copyWith({
    String? id,
    String? fileName,
    String? filePath,
    Uint8List? webBytes,
    String? albumId,
    String? folderId,
    int? totalBytes,
    int? uploadedBytes,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? finishedAt,
    UploadJobStatus? status,
    String? errorMessage,
    bool? compress,
    bool? wifiOnly,
    bool? keepOriginalQuality,
    bool? uploadMetadata,
    bool clearError = false,
    bool? offlinePending,
    int? offlineRetryCount,
    DateTime? nextRetryAt,
    bool clearNextRetryAt = false,
  }) {
    return UploadJobModel(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      webBytes: webBytes ?? this.webBytes,
      albumId: albumId ?? this.albumId,
      folderId: folderId ?? this.folderId,
      totalBytes: totalBytes ?? this.totalBytes,
      uploadedBytes: uploadedBytes ?? this.uploadedBytes,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      compress: compress ?? this.compress,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      keepOriginalQuality: keepOriginalQuality ?? this.keepOriginalQuality,
      uploadMetadata: uploadMetadata ?? this.uploadMetadata,
      offlinePending: offlinePending ?? this.offlinePending,
      offlineRetryCount: offlineRetryCount ?? this.offlineRetryCount,
      nextRetryAt: clearNextRetryAt ? null : (nextRetryAt ?? this.nextRetryAt),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'filePath': filePath,
      'albumId': albumId,
      'folderId': folderId,
      'totalBytes': totalBytes,
      'uploadedBytes': uploadedBytes,
      'createdAt': createdAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'finishedAt': finishedAt?.toIso8601String(),
      'status': status.name,
      'errorMessage': errorMessage,
      'compress': compress,
      'wifiOnly': wifiOnly,
      'keepOriginalQuality': keepOriginalQuality,
      'uploadMetadata': uploadMetadata,
      'offlinePending': offlinePending,
      'offlineRetryCount': offlineRetryCount,
      'nextRetryAt': nextRetryAt?.toIso8601String(),
    };
  }

  factory UploadJobModel.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? UploadJobStatus.queued.name;
    final status = UploadJobStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => UploadJobStatus.queued,
    );

    return UploadJobModel(
      id: json['id'] as String,
      fileName: json['fileName'] as String? ?? 'Untitled',
      filePath: json['filePath'] as String? ?? '',
      albumId: json['albumId'] as String?,
      folderId: json['folderId'] as String?,
      totalBytes: json['totalBytes'] as int? ?? 0,
      uploadedBytes: json['uploadedBytes'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      startedAt: json['startedAt'] != null ? DateTime.tryParse(json['startedAt'] as String) : null,
      finishedAt: json['finishedAt'] != null ? DateTime.tryParse(json['finishedAt'] as String) : null,
      status: status,
      errorMessage: json['errorMessage'] as String?,
      compress: json['compress'] as bool? ?? false,
      wifiOnly: json['wifiOnly'] as bool? ?? false,
      keepOriginalQuality: json['keepOriginalQuality'] as bool? ?? true,
      uploadMetadata: json['uploadMetadata'] as bool? ?? true,
      // Absent on records persisted before Task 19.12 — default to "not
      // an offline retry candidate" so old failed jobs keep requiring a
      // manual Retry tap, same as they always did.
      offlinePending: json['offlinePending'] as bool? ?? false,
      offlineRetryCount: json['offlineRetryCount'] as int? ?? 0,
      nextRetryAt: json['nextRetryAt'] != null
          ? DateTime.tryParse(json['nextRetryAt'] as String)
          : null,
    );
  }
}

class UploadJobMocks {
  static const int defaultTotalBytes = 6 * 1024 * 1024; // ~6MB

  static UploadJobModel createQueued({
    required String id,
    required String fileName,
    String? albumId,
    String? folderId,
    int totalBytes = defaultTotalBytes,
  }) {
    return UploadJobModel(
      id: id,
      fileName: fileName,
      filePath: '',
      albumId: albumId,
      folderId: folderId,
      totalBytes: totalBytes,
      uploadedBytes: 0,
      createdAt: DateTime.now(),
      startedAt: null,
      finishedAt: null,
      status: UploadJobStatus.queued,
      errorMessage: null,
    );
  }
}
