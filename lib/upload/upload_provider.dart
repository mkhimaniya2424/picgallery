import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/media_model.dart';
import '../providers/auth_providers.dart';
import '../services/media_upload_service.dart';
import 'upload_network_gate.dart';
import 'upload_state.dart';

/// Provider for a single upload job.
///
/// Task 19.9: This is a separate provider from the upload queue.
/// It exposes progress/success/failure driven by [MediaUploadService].
final uploadProvider =
    StateNotifierProvider.autoDispose<UploadController, UploadState>(
  (ref) => UploadController(
    ref: ref,
    mediaUploadService: MediaUploadService(
      apiClient: ref.read(apiClientProvider),
    ),
  ),
);

/// Riverpod notifier for uploading a single file.
class UploadController extends StateNotifier<UploadState> {
  UploadController(
      {required Ref ref, required MediaUploadService mediaUploadService})
      : _ref = ref,
        _service = mediaUploadService,
        super(const UploadState.initial());

  final Ref _ref;
  final MediaUploadService _service;

  DateTime? _lastProgressUpdate;

  /// Uploads the given file bytes to the backend.
  ///
  /// Notes:
  /// - [filePath] must be accessible on device.
  /// - [contentType] must be a recognized backend type, e.g.
  ///   `image/jpeg` / `video/mp4`.
  Future<MediaModel> startUpload({
    required String jobId,
    required String filePath,
    required String fileName,
    required String contentType,
    String? albumId,
    String? folderId,
    void Function(int sentBytes, int totalBytes)? onProgress,
  }) async {
    // reset
    _lastProgressUpdate = null;
    state = state.copyWith(
      status: UploadStatus.uploading,
      progress: 0.0,
      sentBytes: 0,
      totalBytes: 0,
      errorMessage: null,
      uploadedMediaId: null,
      uploadedMediaFileName: null,
      currentJobId: jobId,
      currentFileName: fileName,
    );

    // Task 4: honor the global "Wi-Fi Only Uploads" setting for this
    // entry point too — same [canUploadNow] gate the batch queue uses,
    // so the policy isn't duplicated/half-implemented per upload path.
    // A single upload has no queue to defer into, so a blocked upload
    // simply fails fast with a clear, actionable message rather than
    // silently sending over mobile data.
    final gate = await canUploadNow(_ref);
    if (!gate.canUpload) {
      final message = gate.reason ?? 'Waiting for Wi-Fi to upload';
      state = state.copyWith(
        status: UploadStatus.failure,
        errorMessage: message,
      );
      throw StateError(message);
    }

    // Compression is permanently disabled — always stream the file at its
    // original quality, regardless of the global uploadQuality setting.
    // Using filePath directly lets Dio stream the file in chunks so large
    // videos never cause an OOM.
    final fileLength = await File(filePath).length();

    try {
      MediaModel created = await _service.upload(
        bytes: null,
        filePath: filePath,
        fileName: fileName,
        contentType: contentType,
        sizeBytes: fileLength,
        albumId: albumId,
        folderId: folderId,
        onSendProgress: (sent, total) {
          final resolvedTotal = total > 0 ? total : fileLength;
          final cappedSent = sent > resolvedTotal ? resolvedTotal : sent;
          final isComplete = cappedSent >= resolvedTotal;

          final now = DateTime.now();
          if (!isComplete &&
              _lastProgressUpdate != null &&
              now.difference(_lastProgressUpdate!).inMilliseconds < 150) {
            return;
          }
          _lastProgressUpdate = now;

          final prog = resolvedTotal <= 0 ? 0.0 : (cappedSent / resolvedTotal).clamp(0.0, 1.0);
          state = state.copyWith(
            status: UploadStatus.uploading,
            progress: prog,
            sentBytes: cappedSent,
            totalBytes: resolvedTotal,
            clearError: true,
          );
          onProgress?.call(cappedSent, resolvedTotal);
        },
      );

      state = state.copyWith(
        status: UploadStatus.success,
        progress: 1.0,
        sentBytes: state.totalBytes > 0 ? state.totalBytes : state.sentBytes,
        totalBytes: state.totalBytes,
        uploadedMediaId: created.id,
        uploadedMediaFileName: created.fileName,
        clearError: true,
      );
      return created;
    } catch (e) {
      state = state.copyWith(
        status: UploadStatus.failure,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }
}
