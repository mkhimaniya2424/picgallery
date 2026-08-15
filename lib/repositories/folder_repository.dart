import '../core/network/api_client.dart';
import '../core/utils/app_exceptions.dart';
import '../models/folder_model.dart';

abstract class FolderRepository {
  Future<List<FolderModel>> fetchFolders();

  /// Persists a brand-new folder and returns the stored copy.
  Future<FolderModel> createFolder(FolderModel folder);

  /// Persists changes to an existing folder (matched by [FolderModel.id])
  /// — covers rename, move (parentId), hidden and favorite toggles, and
  /// album-count refreshes. Throws [NotFoundException] if it no longer
  /// exists.
  Future<FolderModel> updateFolder(FolderModel folder);

  /// Removes a folder. Throws [NotFoundException] if it no longer exists.
  Future<void> deleteFolder(String id);
}

/// Pure in-memory repository with lightweight simulated latency.
///
/// No network, no db, no local persistence (per brief). Starts with an
/// EMPTY collection — no seed/demo/placeholder folders. Swapping this
/// for a real backend later means writing one new class that implements
/// [FolderRepository] and wiring it into `folderRepositoryProvider` —
/// no screen changes needed.
class InMemoryFolderRepository implements FolderRepository {
  InMemoryFolderRepository({this.latency = const Duration(milliseconds: 420)});

  final Duration latency;

  final List<FolderModel> _folders = [];

  @override
  Future<List<FolderModel>> fetchFolders() async {
    await Future.delayed(latency);
    return List<FolderModel>.from(_folders);
  }

  @override
  Future<FolderModel> createFolder(FolderModel folder) async {
    await Future.delayed(latency ~/ 2);
    _folders.add(folder);
    return folder;
  }

  @override
  Future<FolderModel> updateFolder(FolderModel folder) async {
    await Future.delayed(latency ~/ 2);
    final idx = _folders.indexWhere((f) => f.id == folder.id);
    if (idx == -1) {
      throw NotFoundException('Folder "${folder.id}" no longer exists');
    }
    _folders[idx] = folder;
    return folder;
  }

  @override
  Future<void> deleteFolder(String id) async {
    await Future.delayed(latency ~/ 2);
    final existed = _folders.any((f) => f.id == id);
    if (!existed) {
      throw NotFoundException('Folder "$id" no longer exists');
    }
    _folders.removeWhere((f) => f.id == id);
  }
}

/// API-backed [FolderRepository], talking to `app/api/routes/folders.py`
/// (`GET/POST/PATCH/DELETE /folders`) via [ApiClient] — see
/// [ApiAlbumRepository]'s doc comment for why this matters: it's what
/// makes folder ids real server UUIDs instead of client-side
/// placeholders that fail UUID validation elsewhere (e.g. uploading
/// media into a folder).
class ApiFolderRepository implements FolderRepository {
  ApiFolderRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  List<FolderModel> _mapList(dynamic json) {
    final list = json as List<dynamic>;
    return list
        .map((e) => FolderModel.fromApiJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<FolderModel>> fetchFolders() async {
    final json = await _apiClient.get('/folders');
    return _mapList(json);
  }

  @override
  Future<FolderModel> createFolder(FolderModel folder) async {
    final json = await _apiClient.post('/folders', body: folder.toCreateJson());
    return FolderModel.fromApiJson(json as Map<String, dynamic>);
  }

  @override
  Future<FolderModel> updateFolder(FolderModel folder) async {
    // Same reasoning as ApiAlbumRepository.updateAlbum: [folder] already
    // carries the final desired state, so a null parentId here means
    // "should be cleared", derived into the explicit clear_parent flag
    // the backend requires.
    final body = folder.toUpdateJson(clearParent: folder.parentId == null);
    try {
      final json = await _apiClient.patch('/folders/${folder.id}', body: body);
      return FolderModel.fromApiJson(json as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        throw NotFoundException('Folder "${folder.id}" no longer exists');
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteFolder(String id) async {
    try {
      await _apiClient.delete('/folders/$id');
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        throw NotFoundException('Folder "$id" no longer exists');
      }
      rethrow;
    }
  }
}