import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../models/share_link_model.dart';
import '../repositories/share_link_repository.dart';
import 'auth_providers.dart';

final shareLinkRepositoryProvider = Provider<ShareLinkRepository>((ref) {
  return ShareLinkRepository(apiClient: ref.watch(apiClientProvider));
});

/// Studio-side controller for a single album's share link — replaces
/// the old local-only `ShareLinkNotifier`, which stored links purely on
/// the device (`ShareLinkLocalStore`) and never touched the backend, so
/// a link/QR generated on the studio's phone only ever existed on that
/// phone. This talks to the real `/share-links` API instead, so any
/// link it creates is a real row a guest's phone can actually resolve.
///
/// Scoped per-album (via `.family`) rather than loading every link for
/// every album up front — `ShareSettingsScreen` only ever needs the one
/// album it's showing.
class ShareLinkController extends ChangeNotifier {
  ShareLinkController({required ShareLinkRepository repository, required this.albumId})
      : _repo = repository;

  final ShareLinkRepository _repo;
  final String albumId;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  GalleryShareLink? _activeLink;
  GalleryShareLink? get activeLink => _activeLink;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // `list_share_links` already orders by `created_at desc`, so the
      // first non-revoked link is the current one; if every link for
      // this album has been revoked, fall back to the most recent one
      // so its analytics/"Revoked" status still has something to show.
      final links = await _repo.fetchLinks(albumId: albumId);
      _activeLink = links.isEmpty
          ? null
          : links.firstWhere((l) => !l.isRevoked, orElse: () => links.first);
    } catch (e) {
      _error = e is ApiException ? e.message : e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<GalleryShareLink> createOrUpdate({
    String? clientId,
    bool clearClient = false,
    String? password,
    bool clearPassword = false,
    DateTime? expiresAt,
    bool clearExpiry = false,
    required bool allowDownload,
    required bool showWatermark,
  }) async {
    final current = _activeLink;
    final GalleryShareLink result;
    if (current == null || current.isRevoked) {
      result = await _repo.createLink(
        albumId: albumId,
        clientId: clientId,
        password: password,
        expiresAt: expiresAt,
        allowDownload: allowDownload,
        showWatermark: showWatermark,
      );
    } else {
      result = await _repo.updateLink(
        id: current.id,
        clientId: clientId,
        clearClient: clearClient,
        password: password,
        clearPassword: clearPassword,
        expiresAt: expiresAt,
        clearExpiry: clearExpiry,
        allowDownload: allowDownload,
        showWatermark: showWatermark,
      );
    }
    _activeLink = result;
    notifyListeners();
    return result;
  }

  Future<void> revoke() async {
    final current = _activeLink;
    if (current == null) return;
    _activeLink = await _repo.updateLink(id: current.id, isRevoked: true);
    notifyListeners();
  }
}

final shareLinkControllerProvider =
    ChangeNotifierProvider.family<ShareLinkController, String>((ref, albumId) {
  final controller = ShareLinkController(
    repository: ref.watch(shareLinkRepositoryProvider),
    albumId: albumId,
  );
  Future.microtask(controller.load);
  return controller;
});

/// What [PublicGalleryController] is currently showing — distinct
/// statuses so `SharedGalleryScreen` can render the right message
/// instead of a generic "something went wrong" for every failure mode.
enum PublicGalleryStatus {
  loading,
  needsPassword,
  wrongPassword,
  notFound,
  albumDeleted,
  revoked,
  expired,
  unauthorized,
  downloadsDisabled,
  error,
  loaded,
}

/// Guest-side controller for viewing a shared gallery by [token] — the
/// real counterpart to [ShareLinkController]. Scoped per-token so
/// `SharedGalleryScreen` (reached via a `picgallery://shared/{token}`
/// deep link or "Preview Client View") gets a fresh instance per link.
class PublicGalleryController extends ChangeNotifier {
  PublicGalleryController({required ShareLinkRepository repository, required this.token})
      : _repo = repository;

  final ShareLinkRepository _repo;
  final String token;

  PublicGalleryStatus _status = PublicGalleryStatus.loading;
  PublicGalleryStatus get status => _status;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  PublicGalleryData? _data;
  PublicGalleryData? get data => _data;

  /// The password that successfully unlocked this gallery, remembered
  /// so [recordDownload] can re-send it. `/public/share-links/{token}`
  /// isn't session-based — every request re-validates the password
  /// server-side (`_assert_password_ok`), including the download-record
  /// endpoint. Previously nothing kept this around after [unlock], so
  /// every download from a password-protected gallery silently failed
  /// its 401 in [recordDownload]'s catch-all: `downloads_count` never
  /// incremented and no Download History row was ever written for any
  /// private gallery, even though the actual file save (which doesn't
  /// go through this endpoint) worked fine — a studio just never saw
  /// who downloaded what from their password-protected shares.
  String? _password;

  /// Exposes [_password] so callers that need to re-authenticate against
  /// this same gallery from elsewhere (e.g. kicking off a face search via
  /// `/public/share-links/{token}/face-search`, which is password-gated
  /// exactly like every other endpoint on a private link) don't have to
  /// re-prompt for a password the guest already entered once this session.
  String? get password => _password;

  /// Runs once on creation: checks whether the link needs a passcode
  /// before ever fetching (and counting a view for) the full gallery.
  Future<void> checkStatus() async {
    debugPrint('[API_LOOKUP_DEBUG] PublicGalleryController checking status for token/shareId: $token');
    _status = PublicGalleryStatus.loading;
    notifyListeners();

    try {
      final status = await _repo.fetchStatus(token);
      debugPrint('[API_LOOKUP_DEBUG] Status response - requiresPassword: ${status.requiresPassword}, isActive: ${status.isActive}');
      if (!status.isActive) {
        // The status endpoint doesn't distinguish revoked vs. expired
        // (both just collapse to `is_active: false`) — fetching once
        // more against the main endpoint gets the specific 410 reason
        // instead of guessing.
        await unlock();
        return;
      }
      if (status.requiresPassword) {
        _status = PublicGalleryStatus.needsPassword;
        notifyListeners();
      } else {
        await unlock();
      }
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> unlock({String? password}) async {
    debugPrint('[API_LOOKUP_DEBUG] PublicGalleryController unlocking token: $token (hasPassword: ${password != null})');
    _status = PublicGalleryStatus.loading;
    notifyListeners();

    try {
      _data = await _repo.fetchPublicGallery(token: token, password: password);
      _status = PublicGalleryStatus.loaded;
      _password = password;
      debugPrint('[API_LOOKUP_DEBUG] PublicGalleryController successfully loaded album: ${_data?.album.name}');
    } catch (e) {
      _handleError(e, isPasswordAttempt: password != null && password.isNotEmpty);
    }
    notifyListeners();
  }

  void _handleError(Object error, {bool isPasswordAttempt = false}) {
    debugPrint('[API_LOOKUP_DEBUG] PublicGalleryController error for token $token: $error');
    if (error is ApiException) {
      switch (error.statusCode) {
        case 404:
          if (error.message.toLowerCase().contains('no longer available') ||
              error.message.toLowerCase().contains('album')) {
            _status = PublicGalleryStatus.albumDeleted;
          } else {
            _status = PublicGalleryStatus.notFound;
          }
          break;
        case 403:
          _status = PublicGalleryStatus.unauthorized;
          break;
        case 401:
          _status = isPasswordAttempt ? PublicGalleryStatus.wrongPassword : PublicGalleryStatus.needsPassword;
          break;
        case 410:
          _status = error.message.toLowerCase().contains('revoked')
              ? PublicGalleryStatus.revoked
              : PublicGalleryStatus.expired;
          break;
        default:
          _status = PublicGalleryStatus.error;
          _errorMessage = error.message;
      }
    } else {
      _status = PublicGalleryStatus.error;
      _errorMessage = "Couldn't reach the server. Check your connection and try again.";
    }
  }

  /// Fire-and-forget, same as the old local `incrementDownloads` this
  /// replaces — a failed analytics/history write shouldn't block the
  /// download itself, which has already happened by the time this is
  /// called from the viewer/player screens.
  ///
  /// Defaults [password] to whatever unlocked this gallery ([_password])
  /// — callers (`ImageViewerScreen`/`VideoPlayerScreen`) never had the
  /// password to pass in the first place, so without this default every
  /// call against a private gallery re-validated with `password: null`
  /// and 401'd every time. An explicit [password] argument still wins,
  /// for any future caller that has a fresher one than what's cached.
  Future<void> recordDownload({String? password, String? mediaId}) async {
    try {
      await _repo.recordDownload(
        token: token,
        password: password ?? _password,
        mediaId: mediaId,
      );
    } catch (_) {
      // Best-effort only.
    }
  }
}

final publicGalleryProvider =
    ChangeNotifierProvider.family<PublicGalleryController, String>((ref, token) {
  final controller = PublicGalleryController(
    repository: ref.watch(shareLinkRepositoryProvider),
    token: token,
  );
  Future.microtask(controller.checkStatus);
  return controller;
});