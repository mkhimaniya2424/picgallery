import 'package:dio/dio.dart';

import '../core/network/api_client.dart';
import '../models/media_model.dart';

class MediaUploadService {
  MediaUploadService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<MediaModel> upload({
    List<int>? bytes,
    String? filePath,
    Stream<List<int>> Function()? streamData,
    String? webBlobUrl,
    required String fileName,
    required String contentType,
    required int sizeBytes,
    String? albumId,
    String? folderId,
    void Function(int sentBytes, int totalBytes)? onSendProgress,
  }) async {
    final query = <String, String>{
      if (albumId != null) 'album_id': albumId,
      if (folderId != null) 'folder_id': folderId,
    };
    final path = query.isEmpty
        ? '/media/upload'
        : '/media/upload?${Uri(queryParameters: query).query}';

    if (webBlobUrl != null) {
      // Large web file: bypass Dio entirely and stream natively via XHR
      final response = await _apiClient.uploadLargeFileWeb(
        path,
        blobUrl: webBlobUrl,
        fileName: fileName,
        contentType: contentType,
        onSendProgress: onSendProgress,
      );
      return MediaModel.fromApiJson(response as Map<String, dynamic>);
    }

    MultipartFile file;
    if (filePath != null && filePath.isNotEmpty) {
      file = await MultipartFile.fromFile(filePath,
          filename: fileName, contentType: DioMediaType.parse(contentType));
    } else if (streamData != null) {
      // Large web file fallback (though webBlobUrl should be used instead).
      file = MultipartFile.fromStream(
        streamData,
        sizeBytes,
        filename: fileName,
        contentType: DioMediaType.parse(contentType),
      );
    } else if (bytes != null) {
      file = MultipartFile.fromBytes(bytes,
          filename: fileName, contentType: DioMediaType.parse(contentType));
    } else {
      throw ArgumentError('One of bytes, filePath, streamData or webBlobUrl must be provided');
    }

    final formData = FormData.fromMap({'file': file});
    final response = await _apiClient.postMultipart(path,
        data: formData, onSendProgress: onSendProgress);
    return MediaModel.fromApiJson(response as Map<String, dynamic>);
  }

  Future<MediaModel> replaceFile({
    required String mediaId,
    List<int>? bytes,
    String? filePath,
    Stream<List<int>> Function()? streamData,
    required String fileName,
    required String contentType,
    int sizeBytes = 0,
    void Function(int sentBytes, int totalBytes)? onSendProgress,
  }) async {
    final path = '/media/$mediaId/file';

    MultipartFile file;
    if (filePath != null && filePath.isNotEmpty) {
      file = await MultipartFile.fromFile(filePath,
          filename: fileName, contentType: DioMediaType.parse(contentType));
    } else if (streamData != null) {
      file = MultipartFile.fromStream(
        streamData,
        sizeBytes,
        filename: fileName,
        contentType: DioMediaType.parse(contentType),
      );
    } else if (bytes != null) {
      file = MultipartFile.fromBytes(bytes,
          filename: fileName, contentType: DioMediaType.parse(contentType));
    } else {
      throw ArgumentError('One of bytes, filePath or streamData must be provided');
    }

    final formData = FormData.fromMap({'file': file});
    final response = await _apiClient.putMultipart(path,
        data: formData, onSendProgress: onSendProgress);
    return MediaModel.fromApiJson(response as Map<String, dynamic>);
  }
}
