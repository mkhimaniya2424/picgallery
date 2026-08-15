import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../models/download_history_model.dart';
import '../models/user.dart' show AppUserRole;
import '../providers/auth_providers.dart' show apiClientProvider, authStateProvider;
import '../storage/download_history_local_store.dart';

enum DownloadHistoryFilter {
  all,
  photos,
  videos,
}

enum DownloadHistorySort {
  recent,
  name,
  size,
}

/// API-backed: loads from `GET /download-history` (studio accounts) or
/// `GET /client/download-history` (client accounts, see [isClientUser]),
/// mirroring results
/// into [DownloadHistoryLocalStore] for offline reads (same pattern as
/// `CachingMediaRepository` — mutations always go straight to the API
/// and fail as they always did with no connection; only reads fall back
/// to the cache).
///
/// Delete/Clear are the one exception: the backend has no DELETE route
/// for download history, so those stay client-side — see
/// [DownloadHistoryLocalStore]'s "dismissed ids" doc for why that's
/// still durable across reloads instead of just hiding-then-reappearing.
class DownloadHistoryController extends ChangeNotifier {
  DownloadHistoryController({
    required this.apiClient,
    required this.store,
    this.isClientUser = false,
  });

  final ApiClient apiClient;
  final DownloadHistoryLocalStore store;

  /// True for a logged-in client account. `GET /download-history` is
  /// studio-only (403s for a client token) — clients have their own
  /// `GET /client/download-history` instead, which returns their own
  /// downloads across every studio rather than one studio's activity.
  final bool isClientUser;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _lastError;
  String? get lastError => _lastError;

  String _searchQuery = '';
  DownloadHistoryFilter _filter = DownloadHistoryFilter.all;
  DownloadHistorySort _sort = DownloadHistorySort.recent;

  final List<DownloadHistoryModel> _items = [];
  Set<String> _dismissedIds = {};

  List<DownloadHistoryModel> get items => List.unmodifiable(_items);

  String get searchQuery => _searchQuery;
  DownloadHistoryFilter get filter => _filter;
  DownloadHistorySort get sort => _sort;

  // Undo buffer
  List<DownloadHistoryModel>? _undoSnapshot;
  String? _undoDeletedId;

  List<DownloadHistoryModel> get filteredSorted {
    Iterable<DownloadHistoryModel> list = _items;

    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((e) => e.fileName.toLowerCase().contains(q));
    }

    switch (_filter) {
      case DownloadHistoryFilter.photos:
        list = list.where((e) => e.mediaType == MediaType.photo);
        break;
      case DownloadHistoryFilter.videos:
        list = list.where((e) => e.mediaType == MediaType.video);
        break;
      case DownloadHistoryFilter.all:
        break;
    }

    final out = list.toList();
    switch (_sort) {
      case DownloadHistorySort.recent:
        out.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
        break;
      case DownloadHistorySort.name:
        out.sort((a, b) =>
            a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()));
        break;
      case DownloadHistorySort.size:
        out.sort((a, b) => b.size.compareTo(a.size));
        break;
    }

    return out;
  }

  bool _isUnreachable(Object error) =>
      error is ApiException && error.statusCode == 0;

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      _dismissedIds = await store.loadDismissedIds();

      final response = await apiClient.get(
        isClientUser ? '/client/download-history' : '/download-history',
      );
      final fetched = (response as List<dynamic>)
          .map((e) => DownloadHistoryModel.fromApiJson(e as Map<String, dynamic>))
          .toList();

      // Mirror the full (undismissed-filtered-out-locally) response for
      // offline reads, then apply local dismissals for display.
      await store.saveCache(fetched);

      _items
        ..clear()
        ..addAll(fetched.where((e) => !_dismissedIds.contains(e.id)));
      _lastError = null;
    } on ApiException catch (e) {
      if (_isUnreachable(e)) {
        // No connection — serve read-only from the last known cache.
        final cached = await store.loadCache();
        _items
          ..clear()
          ..addAll(cached.where((e) => !_dismissedIds.contains(e.id)));
        _lastError = 'Could not reach the server. Showing cached history.';
      } else {
        _lastError = e.message;
      }
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();

  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  void setFilter(DownloadHistoryFilter value) {
    _filter = value;
    notifyListeners();
  }

  void setSort(DownloadHistorySort value) {
    _sort = value;
    notifyListeners();
  }

  /// Removes [id] from view and remembers it as dismissed so it stays
  /// hidden on future reloads — there's no backend DELETE to call, see
  /// class doc.
  Future<void> deleteOne(String id) async {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx == -1) return;

    // Snapshot only the removed item for undo.
    _undoDeletedId = id;
    _undoSnapshot = [_items[idx]];

    _items.removeAt(idx);
    _dismissedIds.add(id);
    await store.saveDismissedIds(_dismissedIds);
    notifyListeners();
  }

  Future<void> clearAll() async {
    // Snapshot whole list for undo.
    _undoDeletedId = null;
    _undoSnapshot = List<DownloadHistoryModel>.from(_items);

    _dismissedIds.addAll(_items.map((e) => e.id));
    _items.clear();
    await store.saveDismissedIds(_dismissedIds);
    notifyListeners();
  }

  /// Undo last delete/clear. Un-dismisses the affected ids (so they
  /// stay visible on future reloads too) and restores them from the
  /// local snapshot immediately, without waiting on a network refetch.
  Future<void> undo() async {
    final snapshot = _undoSnapshot;
    if (snapshot == null || snapshot.isEmpty) return;

    if (_undoDeletedId != null) {
      final existing = _items.any((e) => e.id == _undoDeletedId);
      if (!existing) {
        _items.addAll(snapshot);
      }
      _dismissedIds.remove(_undoDeletedId);
    } else {
      // Undo clear: restore everything.
      _items
        ..clear()
        ..addAll(snapshot);
      _dismissedIds.removeAll(snapshot.map((e) => e.id));
    }

    _undoDeletedId = null;
    _undoSnapshot = null;

    await store.saveDismissedIds(_dismissedIds);
    notifyListeners();
  }
}

final downloadHistoryProvider =
    ChangeNotifierProvider<DownloadHistoryController>((ref) {
  final isClientUser =
      ref.read(authStateProvider).user?.role == AppUserRole.client;
  final controller = DownloadHistoryController(
    apiClient: ref.read(apiClientProvider),
    store: DownloadHistoryLocalStore(),
    isClientUser: isClientUser,
  );
  // Load eagerly.
  Future.microtask(controller.load);
  return controller;
});
