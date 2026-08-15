import '../core/utils/app_exceptions.dart';
import '../models/album_model.dart';
import '../storage/album_local_store.dart';
import 'album_repository.dart';

/// Hive-backed [AlbumRepository].
///
/// Keeps an in-memory cache to optimize read operations after the initial fetch.
class HiveAlbumRepository implements AlbumRepository {
  HiveAlbumRepository({AlbumLocalStore? store})
      : _store = store ?? AlbumLocalStore();

  final AlbumLocalStore _store;
  List<AlbumModel>? _cache;

  Future<List<AlbumModel>> _ensureLoaded() async {
    _cache ??= await _store.load();
    return _cache!;
  }

  @override
  Future<List<AlbumModel>> fetchAlbums() async {
    final list = await _ensureLoaded();
    return List<AlbumModel>.from(list);
  }

  @override
  Future<AlbumModel> createAlbum(AlbumModel album) async {
    final list = await _ensureLoaded();
    final next = [...list, album];
    _cache = next;
    await _store.saveAll(next);
    return album;
  }

  @override
  Future<AlbumModel> updateAlbum(AlbumModel album) async {
    final list = await _ensureLoaded();
    final idx = list.indexWhere((a) => a.id == album.id);
    if (idx == -1) {
      throw NotFoundException('Album "${album.id}" no longer exists');
    }
    final next = [...list];
    next[idx] = album;
    _cache = next;
    await _store.saveAll(next);
    return album;
  }

  @override
  Future<void> deleteAlbum(String id) async {
    final list = await _ensureLoaded();
    final existed = list.any((a) => a.id == id);
    if (!existed) {
      throw NotFoundException('Album "$id" no longer exists');
    }
    final next = list.where((a) => a.id != id).toList();
    _cache = next;
    await _store.saveAll(next);
  }
}
