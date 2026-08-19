import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/studio_model.dart';
import '../repositories/studio_profile_repository.dart';
import '../repositories/studio_repository.dart';
import 'auth_providers.dart';

final studioRepositoryProvider = Provider<StudioDirectoryRepository>((ref) {
  return ApiStudioRepository(apiClient: ref.watch(apiClientProvider));
});

/// A studio editing its OWN profile (logo, cover photo, Showcase
/// Portfolio) — separate from [studioRepositoryProvider] above, which is
/// for a *client* browsing/favoriting *other* studios' public profiles.
final studioProfileRepositoryProvider = Provider<StudioProfileRepository>((ref) {
  return StudioProfileRepository(apiClient: ref.watch(apiClientProvider));
});

class StudioNotifier extends ChangeNotifier {
  StudioNotifier(this._repo);

  final StudioDirectoryRepository _repo;

  bool _isLoadingFavorites = false;
  String? _favoritesError;

  bool get isLoadingFavorites => _isLoadingFavorites;
  String? get favoritesError => _favoritesError;

  bool _isLoadingDirectory = false;
  String? _directoryError;

  bool get isLoadingDirectory => _isLoadingDirectory;
  String? get directoryError => _directoryError;

  /// Ids currently mid-flight on a connect/withdraw call — lets the UI
  /// disable just that studio's button instead of the whole screen
  /// while the optimistic update is unconfirmed.
  final Set<String> _pendingConnectionIds = {};
  Set<String> get pendingConnectionIds => Set.unmodifiable(_pendingConnectionIds);

  List<StudioModel> _studios = [];

  String _searchQuery = '';
  String _selectedCategory = 'All';

  List<StudioModel> get studios => List.unmodifiable(_studios);
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;

  List<StudioModel> get filteredStudios {
    return _studios.where((studio) {
      final matchesQuery = studio.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          studio.location.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          studio.categories.any((c) => c.toLowerCase().contains(_searchQuery.toLowerCase()));

      final matchesCategory = _selectedCategory == 'All' ||
          studio.categories.contains(_selectedCategory);

      return matchesQuery && matchesCategory;
    }).toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  /// Loads the directory only if it hasn't been loaded yet (and isn't
  /// already loading) — safe to call from every screen's `initState`
  /// (Discover Studios, Studio Profile) without triggering duplicate
  /// fetches when the user navigates between them.
  Future<void> ensureDirectoryLoaded() {
    if (_studios.isNotEmpty || _isLoadingDirectory) return Future.value();
    return loadDirectory();
  }

  /// Fetches the real studio directory from `GET /studios`. Replaces
  /// [_studios] wholesale — search/category filters stay applied
  /// client-side via [filteredStudios] on whatever comes back.
  Future<void> loadDirectory() async {
    _isLoadingDirectory = true;
    _directoryError = null;
    notifyListeners();

    try {
      _studios = await _repo.fetchDirectory();
    } catch (e) {
      _directoryError = 'Could not load studios. Pull down to retry.';
      if (kDebugMode) debugPrint('loadDirectory failed: $e');
    } finally {
      _isLoadingDirectory = false;
      notifyListeners();
    }
  }

  /// Updates the local cached studio branding for the currently edited
  /// studio so the app reflects a newly uploaded logo or cover before a
  /// full directory refresh finishes.
  void updateCachedBranding({String? logoUrl, String? coverUrl}) {
    if (_studios.isEmpty) return;

    for (var i = 0; i < _studios.length; i++) {
      final studio = _studios[i];
      if (logoUrl != null || coverUrl != null) {
        _studios[i] = studio.copyWith(
          logoUrl: logoUrl ?? studio.logoUrl,
          coverUrl: coverUrl ?? studio.coverUrl,
        );
      }
    }
    notifyListeners();
  }

  /// Fetches the client's real favorited studios from the backend
  /// (`GET /studios/favorites`) and merges them into [_studios]:
  /// existing directory entries with a matching id are simply flagged
  /// `isFavorite: true`, and any favorite the backend knows about that
  /// isn't already loaded (e.g. Favorite Studios opened before
  /// Discover Studios ever loaded the directory) is appended so it's
  /// still visible on the Favorite Studios screen.
  Future<void> loadFavorites() async {
    _isLoadingFavorites = true;
    _favoritesError = null;
    notifyListeners();

    try {
      final favorites = await _repo.fetchFavoriteStudios();

      // Anything not in this list anymore was unfavorited elsewhere
      // (e.g. another device) — clear stale local flags first.
      for (var i = 0; i < _studios.length; i++) {
        if (_studios[i].isFavorite) {
          _studios[i] = _studios[i].copyWith(isFavorite: false);
        }
      }

      for (final favorite in favorites) {
        final index = _studios.indexWhere((s) => s.id == favorite.id);
        if (index != -1) {
          _studios[index] = _studios[index].copyWith(isFavorite: true);
        } else {
          _studios.add(favorite);
        }
      }
    } catch (e) {
      _favoritesError = 'Could not load favorite studios. Pull down to retry.';
      if (kDebugMode) debugPrint('loadFavorites failed: $e');
    } finally {
      _isLoadingFavorites = false;
      notifyListeners();
    }
  }

  /// Optimistically flips [id]'s favorite flag, then persists it via
  /// [_repo]. Reverts (and surfaces [favoritesError]) if the call fails,
  /// so the heart icon never lies about the server's actual state.
  Future<void> toggleFavorite(String id) async {
    final index = _studios.indexWhere((studio) => studio.id == id);
    if (index == -1) return;

    final wasFavorite = _studios[index].isFavorite;
    _studios[index] = _studios[index].copyWith(isFavorite: !wasFavorite);
    notifyListeners();

    try {
      if (wasFavorite) {
        await _repo.unfavoriteStudio(id);
      } else {
        await _repo.favoriteStudio(id);
      }
    } catch (e) {
      final revertIndex = _studios.indexWhere((studio) => studio.id == id);
      if (revertIndex != -1) {
        _studios[revertIndex] = _studios[revertIndex].copyWith(isFavorite: wasFavorite);
      }
      _favoritesError = wasFavorite
          ? 'Could not remove from favorites. Try again.'
          : 'Could not add to favorites. Try again.';
      if (kDebugMode) debugPrint('toggleFavorite failed: $e');
      notifyListeners();
    }
  }

  /// Sends a real connection request to studio [id] (`notConnected` ->
  /// `pending`), optimistically, reverting on failure. Does nothing if
  /// [id] isn't `notConnected` (e.g. a double-tap while the request is
  /// already in flight) — [pendingConnectionIds] is what the button
  /// should check to disable itself, not the status. Returns whether
  /// the request succeeded, so the caller can show a one-off snackbar
  /// without depending on [directoryError] staying in sync.
  Future<bool> requestConnection(String id) async {
    final index = _studios.indexWhere((studio) => studio.id == id);
    if (index == -1 || _studios[index].connectionStatus != StudioConnectionStatus.notConnected) {
      return false;
    }

    _pendingConnectionIds.add(id);
    _studios[index] = _studios[index].copyWith(connectionStatus: StudioConnectionStatus.pending);
    notifyListeners();

    try {
      await _repo.connectToStudio(id);
      return true;
    } catch (e) {
      final revertIndex = _studios.indexWhere((studio) => studio.id == id);
      if (revertIndex != -1) {
        _studios[revertIndex] =
            _studios[revertIndex].copyWith(connectionStatus: StudioConnectionStatus.notConnected);
      }
      _directoryError = 'Could not send connection request. Try again.';
      if (kDebugMode) debugPrint('requestConnection failed: $e');
      return false;
    } finally {
      _pendingConnectionIds.remove(id);
      notifyListeners();
    }
  }

  /// Withdraws [id]'s pending request (`pending` -> `notConnected`),
  /// optimistically, reverting on failure. Does nothing if [id] isn't
  /// currently `pending`. Returns whether the withdrawal succeeded —
  /// same reasoning as [requestConnection].
  Future<bool> withdrawConnectionRequest(String id) async {
    final index = _studios.indexWhere((studio) => studio.id == id);
    if (index == -1 || _studios[index].connectionStatus != StudioConnectionStatus.pending) {
      return false;
    }

    _pendingConnectionIds.add(id);
    _studios[index] = _studios[index].copyWith(connectionStatus: StudioConnectionStatus.notConnected);
    notifyListeners();

    try {
      await _repo.withdrawStudioRequest(id);
      return true;
    } catch (e) {
      final revertIndex = _studios.indexWhere((studio) => studio.id == id);
      if (revertIndex != -1) {
        _studios[revertIndex] =
            _studios[revertIndex].copyWith(connectionStatus: StudioConnectionStatus.pending);
      }
      _directoryError = 'Could not withdraw request. Try again.';
      if (kDebugMode) debugPrint('withdrawConnectionRequest failed: $e');
      return false;
    } finally {
      _pendingConnectionIds.remove(id);
      notifyListeners();
    }
  }
}

final studioProvider = ChangeNotifierProvider<StudioNotifier>((ref) {
  return StudioNotifier(ref.watch(studioRepositoryProvider));
});