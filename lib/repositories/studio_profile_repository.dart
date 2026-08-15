import '../core/network/api_client.dart';
import '../core/utils/app_exceptions.dart';
import '../services/studio_media_upload_service.dart';

/// A studio managing its OWN profile — logo, cover photo, and Showcase
/// Portfolio grid (Edit Studio Profile screen). Deliberately separate
/// from [StudioDirectoryRepository]/`studioRepositoryProvider`, which is
/// about a *client* browsing/favoriting *other* studios' public
/// profiles — different backend routes (`/studios/me/...` vs
/// `/studios/{id}/...`), different caller, different concerns.
class StudioProfileRepository {
  StudioProfileRepository({required ApiClient apiClient, StudioMediaUploadService? uploadService})
      : _apiClient = apiClient,
        _uploadService = uploadService ?? StudioMediaUploadService(apiClient: apiClient);

  final ApiClient _apiClient;
  final StudioMediaUploadService _uploadService;

  /// Uploads/replaces the studio's logo via `POST /studios/me/avatar`.
  /// Returns the new `avatar_url` to display immediately.
  Future<String?> uploadAvatar({
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) {
    return _uploadService.uploadAvatar(bytes: bytes, fileName: fileName, contentType: contentType);
  }

  /// Uploads/replaces the studio's cover photo via `POST /studios/me/cover`.
  /// Returns the new `cover_image_url` to display immediately.
  Future<String?> uploadCover({
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) {
    return _uploadService.uploadCover(bytes: bytes, fileName: fileName, contentType: contentType);
  }

  /// Lists the current studio's Showcase Portfolio images, newest first
  /// (`GET /studios/me/portfolio`).
  Future<List<StudioPortfolioImage>> fetchPortfolio() async {
    final json = await _apiClient.get('/studios/me/portfolio');
    final list = json as List<dynamic>;
    return list
        .map((e) => StudioPortfolioImage.fromApiJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Adds one image to the Showcase Portfolio grid
  /// (`POST /studios/me/portfolio`).
  Future<StudioPortfolioImage> addPortfolioImage({
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) {
    return _uploadService.uploadPortfolioImage(bytes: bytes, fileName: fileName, contentType: contentType);
  }

  /// Removes one image from the Showcase Portfolio grid
  /// (`DELETE /studios/me/portfolio/{id}`). Throws [NotFoundException]
  /// if it was already removed (e.g. another device deleted it first).
  Future<void> deletePortfolioImage(String imageId) async {
    try {
      await _apiClient.delete('/studios/me/portfolio/$imageId');
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        throw NotFoundException('This portfolio image no longer exists.');
      }
      rethrow;
    }
  }

  void dispose() => _uploadService.dispose();
}