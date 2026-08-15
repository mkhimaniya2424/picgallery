import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/share_link_model.dart';
import '../storage/share_link_local_store.dart';

class ShareLinkNotifier extends ChangeNotifier {
  final ShareLinkLocalStore _store;
  final List<GalleryShareLink> _links = [];

  ShareLinkNotifier({ShareLinkLocalStore? store})
      : _store = store ?? ShareLinkLocalStore();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<GalleryShareLink> get allLinks => List.unmodifiable(_links);

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      final loaded = await _store.load();
      _links.clear();
      _links.addAll(loaded);
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  GalleryShareLink? getLinkForAlbum(String albumId) {
    for (final link in _links) {
      if (link.albumId == albumId && !link.revoked) {
        return link;
      }
    }
    // Fallback: look for revoked links if no active one exists, or return null
    return _links.cast<GalleryShareLink?>().firstWhere(
          (l) => l?.albumId == albumId,
          orElse: () => null,
        );
  }

  GalleryShareLink? getLinkById(String linkId) {
    for (final link in _links) {
      if (link.id == linkId) return link;
    }
    return null;
  }

  Future<GalleryShareLink> createOrUpdateLink({
    required String albumId,
    required bool isPublic,
    String? password,
    DateTime? expiryDate,
    required bool allowDownload,
    required bool showWatermark,
  }) async {
    final idx = _links.indexWhere((l) => l.albumId == albumId);
    final now = DateTime.now();

    final link = GalleryShareLink(
      id: idx != -1 ? _links[idx].id : 'sh-${now.microsecondsSinceEpoch}',
      albumId: albumId,
      isPublic: isPublic,
      password: isPublic ? null : password,
      expiryDate: expiryDate,
      allowDownload: allowDownload,
      showWatermark: showWatermark,
      revoked: false,
      viewsCount: idx != -1 ? _links[idx].viewsCount : 0,
      downloadsCount: idx != -1 ? _links[idx].downloadsCount : 0,
      createdAt: idx != -1 ? _links[idx].createdAt : now,
    );

    if (idx == -1) {
      _links.add(link);
    } else {
      _links[idx] = link;
    }

    await _store.saveAll(_links);
    notifyListeners();
    return link;
  }

  Future<void> revokeLink(String linkId) async {
    final idx = _links.indexWhere((l) => l.id == linkId);
    if (idx == -1) return;

    _links[idx] = _links[idx].copyWith(revoked: true);
    await _store.saveAll(_links);
    notifyListeners();
  }

  Future<void> incrementViews(String linkId) async {
    final idx = _links.indexWhere((l) => l.id == linkId);
    if (idx == -1) return;

    _links[idx] = _links[idx].copyWith(viewsCount: _links[idx].viewsCount + 1);
    await _store.saveAll(_links);
    notifyListeners();
  }

  Future<void> incrementDownloads(String linkId) async {
    final idx = _links.indexWhere((l) => l.id == linkId);
    if (idx == -1) return;

    _links[idx] = _links[idx].copyWith(downloadsCount: _links[idx].downloadsCount + 1);
    await _store.saveAll(_links);
    notifyListeners();
  }
}

final shareLinkProvider = ChangeNotifierProvider<ShareLinkNotifier>((ref) {
  final store = ShareLinkLocalStore();
  final notifier = ShareLinkNotifier(store: store);
  Future.microtask(notifier.load);
  return notifier;
});
