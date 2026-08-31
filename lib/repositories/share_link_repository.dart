import '../core/network/api_client.dart';
import '../models/share_link_model.dart';

/// API-backed repository for `app/api/routes/share_links.py` — both the
/// studio-side CRUD router (`/share-links`, auth required) and the
/// public, token-only guest router (`/public/share-links`, no auth).
///
/// This is the single real implementation; there is no in-memory /
/// local-only variant anymore (see `ShareLinkController`'s doc comment
/// for why the old `ShareLinkLocalStore` had to go — a share link that
/// only exists on the studio's own phone can never be resolved by a
/// guest scanning its QR code or opening its link).
class ShareLinkRepository {
  ShareLinkRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  List<GalleryShareLink> _mapList(dynamic json) {
    final list = json as List<dynamic>;
    return list
        .map((e) => GalleryShareLink.fromApiJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  // ---------------------------------------------------------------------
  // Studio-side (auth required)
  // ---------------------------------------------------------------------

  Future<List<GalleryShareLink>> fetchLinks({String? albumId, bool activeOnly = false}) async {
    final query = <String>[];
    if (albumId != null) query.add('album_id=$albumId');
    if (activeOnly) query.add('active_only=true');
    final path = '/share-links${query.isEmpty ? '' : '?${query.join('&')}'}';
    final json = await _apiClient.get(path);
    return _mapList(json);
  }

  Future<GalleryShareLink> createLink({
    required String albumId,
    String? clientId,
    String? password,
    DateTime? expiresAt,
    bool allowDownload = true,
    bool showWatermark = false,
  }) async {
    final body = {
      'album_id': albumId,
      if (clientId != null && clientId.isNotEmpty) 'client_id': clientId,
      if (password != null && password.isNotEmpty) 'password': password,
      if (expiresAt != null) 'expires_at': expiresAt.toUtc().toIso8601String(),
      'allow_download': allowDownload,
      'show_watermark': showWatermark,
    };
    final json = await _apiClient.post('/share-links', body: body);
    return GalleryShareLink.fromApiJson(json as Map<String, dynamic>);
  }

  /// Every field is optional here on purpose (`ShareLinkUpdate` uses
  /// `exclude_unset` server-side) — omitting a field leaves it
  /// untouched, [clearPassword]/[clearExpiry] are the explicit way to
  /// null one out, and a blank/omitted [password] on an already
  /// password-protected link means "keep the existing password", never
  /// "remove it" (the backend has no way to send the plaintext back for
  /// prefilling anyway, since it only ever stores the bcrypt hash).
  Future<GalleryShareLink> updateLink({
    required String id,
    String? clientId,
    bool clearClient = false,
    String? password,
    bool clearPassword = false,
    DateTime? expiresAt,
    bool clearExpiry = false,
    bool? allowDownload,
    bool? showWatermark,
    bool? isRevoked,
  }) async {
    final body = {
      if (clientId != null && clientId.isNotEmpty) 'client_id': clientId,
      if (clearClient) 'clear_client': true,
      if (password != null && password.isNotEmpty) 'password': password,
      if (clearPassword) 'clear_password': true,
      if (expiresAt != null) 'expires_at': expiresAt.toUtc().toIso8601String(),
      if (clearExpiry) 'clear_expiry': true,
      if (allowDownload != null) 'allow_download': allowDownload,
      if (showWatermark != null) 'show_watermark': showWatermark,
      if (isRevoked != null) 'is_revoked': isRevoked,
    };
    final json = await _apiClient.patch('/share-links/$id', body: body);
    return GalleryShareLink.fromApiJson(json as Map<String, dynamic>);
  }

  Future<void> deleteLink(String id) async {
    await _apiClient.delete('/share-links/$id');
  }

  // ---------------------------------------------------------------------
  // Public / guest side (optional auth) — used by SharedGalleryScreen
  // ---------------------------------------------------------------------

  Future<ShareLinkStatus> fetchStatus(String token) async {
    final json = await _apiClient.get('/public/share-links/$token/status', withAuth: false);
    return ShareLinkStatus.fromApiJson(json as Map<String, dynamic>);
  }

  /// Fetches the shared album + media. Each successful call counts as
  /// one view server-side, so this should only be called once the
  /// passcode gate (if any) has actually been cleared — never
  /// speculatively, or every rebuild would inflate the view counter.
  Future<PublicGalleryData> fetchPublicGallery({required String token, String? password}) async {
    final query = (password != null && password.isNotEmpty)
        ? '?password=${Uri.encodeQueryComponent(password)}'
        : '';
    final json = await _apiClient.get('/public/share-links/$token$query', withAuth: false);
    return PublicGalleryData.fromApiJson(json as Map<String, dynamic>);
  }

  /// Called right before actually downloading/saving a photo from a
  /// shared gallery — re-validates the password server-side (so a
  /// direct hit on this endpoint can't bypass gallery protection) and,
  /// when [mediaId] is supplied, writes a real Download History row.
  Future<void> recordDownload({
    required String token,
    String? password,
    String? mediaId,
    String? downloaderLabel,
  }) async {
    final body = {
      if (password != null && password.isNotEmpty) 'password': password,
      if (mediaId != null) 'media_id': mediaId,
      if (downloaderLabel != null) 'downloader_label': downloaderLabel,
    };
    await _apiClient.post('/public/share-links/$token/download', body: body, withAuth: false);
  }
}
