import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/media_model.dart';
import '../providers/auth_providers.dart';
import '../services/media_upload_service.dart';
import 'upload_media_prep.dart';
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
  UploadController({required Ref ref, required MediaUploadService mediaUploadService})
      : _ref = ref,
        _service = mediaUploadService,
        super(const UploadState.initial());

  final Ref _ref;
  final MediaUploadService _service;

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

    final bytes = await File(filePath).readAsBytes();

    // Task 5: honor the global "Upload Resolution" setting — same
    // [prepareMediaBytesForUpload] helper the batch queue uses, so
    // "High" vs "Original" behaves identically no matter which upload
    // path the file went through.
    final preparedBytes = await prepareMediaBytesForUpload(
      _ref,
      bytes: bytes,
      contentType: contentType,
    );

    try {
      MediaModel created = await _service.upload(
        bytes: preparedBytes,
        fileName: fileName,
        contentType: contentType,
        albumId: albumId,
        folderId: folderId,
        onSendProgress: (sent, total) {
          final prog = total <= 0 ? 0.0 : (sent / total).clamp(0.0, 1.0);
          state = state.copyWith(
            status: UploadStatus.uploading,
            progress: prog,
            sentBytes: sent,
            totalBytes: total,
            clearError: true,
          );
          onProgress?.call(sent, total);
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

