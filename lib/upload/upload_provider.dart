import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/media_model.dart';
import '../providers/auth_providers.dart';
import '../services/media_upload_service.dart';
import 'upload_state.dart';


/// Provider for a single upload job.
///
/// Task 19.9: This is a separate provider from the upload queue.
/// It exposes progress/success/failure driven by [MediaUploadService].
final uploadProvider =
    StateNotifierProvider.autoDispose<UploadController, UploadState>(
  (ref) => UploadController(
    mediaUploadService: MediaUploadService(
      apiClient: ref.read(apiClientProvider),
    ),
  ),
);


/// Riverpod notifier for uploading a single file.
class UploadController extends StateNotifier<UploadState> {
  UploadController({required MediaUploadService mediaUploadService})
      : _service = mediaUploadService,
        super(const UploadState.initial());

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

    final bytes = await File(filePath).readAsBytes();

    try {
      MediaModel created = await _service.upload(
        bytes: bytes,
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

