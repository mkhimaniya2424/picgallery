import 'package:flutter/material.dart';

import '../core/utils/media_format_utils.dart';
import '../models/admin_dashboard_data.dart';
import '../models/album_model.dart';

import '../models/media_model.dart';
import '../models/studio_client_connection_model.dart';

/// DTOs bridging the FastAPI Admin Dashboard endpoints
/// (`/admin-dashboard/stats`, `/bookings`, `/connections`, `/media`,
/// `/notifications`) onto the plain UI models `AdminDashboardSnapshot`
/// is built from — [StatCardData]/[BookingData]/[ClientData]/
/// [AlbumUploadData]/[NotificationData] (`models/admin_dashboard_data.dart`).
///
/// Same split the backend itself uses between a `*Read` Pydantic schema
/// and the row it's built from (`BookingRead.from_booking`,
/// `MediaRead.from_model`, ...): each class below owns *parsing* one
/// endpoint's response and exposes a `toXxxData()` mapper that produces
/// the dashboard's own shape. [ApiAdminDashboardRepository]
/// (`api_admin_dashboard_repository.dart`) is the only caller — the
/// dashboard screens/providers never see raw JSON or these DTOs.
///
/// Three of these endpoints already have a Task 19.x `fromApiJson`
/// parser on a *different* (richer) domain model — [BookingModel],
/// [StudioClientConnection], [MediaModel] — built for the Booking
/// Management / Connections / Media screens. Rather than re-parsing the
/// same JSON shape twice, the DTOs below reuse those parsers and add
/// only the translation down to the dashboard's simpler cards; only
/// [DashboardStatsDto] and [DashboardNotificationDto] parse JSON
/// directly, since neither `/admin-dashboard/stats` nor the studio-side
/// use of `/notifications` has an existing model to reuse (the existing
/// `NotificationsRepository` maps `/notifications` onto
/// [NotificationAlert] instead — the *client* Alerts tab's shape, not
/// the dashboard's).

// ---------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------

/// Same "first letter of up to the first two words" convention used by
/// [StudioClientConnection.fromApiJson] and the in-memory repository's
/// `addClient`/`inviteClient`.
String dashboardInitialsFrom(String? name) {
  if (name == null || name.trim().isEmpty) return '?';
  final initials = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w[0].toUpperCase())
      .join();
  return initials.isEmpty ? '?' : initials;
}

/// Small fixed palette so API-sourced rows still get a stable, varied
/// gradient (same idea as the in-memory repository picking randomly
/// from a fixed list in `addClient`/`inviteClient`) — deterministic here
/// (hashed off the id) rather than random, so the same row doesn't
/// change color on every refresh.
const List<List<Color>> _dashboardGradients = [
  [Color(0xFF7C5CFF), Color(0xFFA855F7)],
  [Color(0xFFEC4899), Color(0xFFF472B6)],
  [Color(0xFFA855F7), Color(0xFFEC4899)],
  [Color(0xFF22C55E), Color(0xFF7C5CFF)],
];

List<Color> _gradientFor(String id) =>
    _dashboardGradients[id.hashCode.abs() % _dashboardGradients.length];

// ---------------------------------------------------------------------
// Stat cards — GET /admin-dashboard/stats (AdminDashboardStatsRead)
// ---------------------------------------------------------------------

/// Parses `AdminDashboardStatsRead` and turns it into the header stat
/// cards. This endpoint is a single live snapshot with no history
/// behind it (no `/admin-dashboard/analytics` call is made here — see
/// [ApiAdminDashboardRepository.fetchSnapshot]), so unlike the
/// in-memory repository's `_deriveStats()` there's no real trend to
/// show: [sparkline] is left flat and [StatCardData.delta] empty rather
/// than fabricating a wobble or a percentage that isn't backed by
/// anything.
class DashboardStatsDto {
  final int photoCount;
  final int videoCount;
  final int totalMediaCount;
  final int storageUsedBytes;
  final double storageUsedGb;
  final int clientCount;
  final int pendingClientRequests;
  final int sharedGalleryCount;
  final int totalGalleryViews;
  final int totalGalleryDownloads;


  const DashboardStatsDto({
    required this.photoCount,
    required this.videoCount,
    required this.totalMediaCount,
    required this.storageUsedBytes,
    required this.storageUsedGb,
    required this.clientCount,
    required this.pendingClientRequests,
    required this.sharedGalleryCount,
    this.totalGalleryViews = 0,
    this.totalGalleryDownloads = 0,
  });

  factory DashboardStatsDto.fromApiJson(Map<String, dynamic> json) => DashboardStatsDto(
        photoCount: json['photo_count'] as int? ?? 0,
        videoCount: json['video_count'] as int? ?? 0,
        totalMediaCount: json['total_media_count'] as int? ?? 0,
        storageUsedBytes: json['storage_used_bytes'] as int? ?? 0,
        storageUsedGb: (json['storage_used_gb'] as num?)?.toDouble() ?? 0,
        clientCount: json['client_count'] as int? ?? 0,
        pendingClientRequests: json['pending_client_requests'] as int? ?? 0,
        sharedGalleryCount: json['shared_gallery_count'] as int? ?? 0,
        totalGalleryViews: json['total_gallery_views'] as int? ?? 0,
        totalGalleryDownloads: json['total_gallery_downloads'] as int? ?? 0,
      );

  List<double> _flatSparkline(num value) => List.filled(7, value.toDouble());

  String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }



  List<StatCardData> toStatCards() {
    return [
      StatCardData(
        label: 'Total Photos',
        value: _formatCount(photoCount),
        icon: Icons.photo_library_rounded,
        gradient: const [Color(0xFFA855F7), Color(0xFFEC4899)],
        sparkline: _flatSparkline(photoCount),
        delta: '',
        trend: TrendDirection.up,
      ),
      StatCardData(
        label: 'Total Videos',
        value: _formatCount(videoCount),
        icon: Icons.videocam_rounded,
        gradient: const [Color(0xFFEC4899), Color(0xFFF472B6)],
        sparkline: _flatSparkline(videoCount),
        delta: '',
        trend: TrendDirection.up,
      ),
      StatCardData(
        label: 'Active Clients',
        value: '$clientCount',
        icon: Icons.people_alt_rounded,
        gradient: const [Color(0xFF7C5CFF), Color(0xFFEC4899)],
        sparkline: _flatSparkline(clientCount),
        delta: '',
        trend: TrendDirection.up,
      ),
      StatCardData(
        label: 'Pending Requests',
        value: '$pendingClientRequests',
        icon: Icons.pending_actions_rounded,
        gradient: const [Color(0xFFF59E0B), Color(0xFFEC4899)],
        sparkline: _flatSparkline(pendingClientRequests),
        delta: '',
        trend: pendingClientRequests == 0 ? TrendDirection.up : TrendDirection.down,
      ),
      StatCardData(
        // Was hard-coded to "X.X GB" regardless of scale, so a studio
        // that had barely started uploading (a few MB in) saw "0.0 GB"
        // — technically correct, but useless. storageUsedBytes was
        // already being parsed from the API and just sitting unused;
        // MediaFormatUtils.formatFileSize picks the right unit
        // (B/KB/MB/GB/TB) off the real byte count, same formatting
        // every other file-size display in the app already uses.
        label: 'Storage Used',
        value: MediaFormatUtils.formatFileSize(storageUsedBytes),
        icon: Icons.storage_rounded,
        gradient: const [Color(0xFF7C5CFF), Color(0xFFA855F7)],
        sparkline: _flatSparkline(storageUsedGb),
        delta: '',
        trend: TrendDirection.up,
      ),
      StatCardData(
        label: 'Shared Galleries',
        value: '$sharedGalleryCount',
        icon: Icons.ios_share_rounded,
        gradient: const [Color(0xFF22C55E), Color(0xFFA855F7)],
        sparkline: _flatSparkline(sharedGalleryCount),
        delta: '',
        trend: TrendDirection.up,
      ),
    ];
  }
}

// ---------------------------------------------------------------------
// Bookings — GET /bookings (BookingRead), reusing BookingModel.fromApiJson
// ---------------------------------------------------------------------

/// Wraps a `BookingRead` row (already parsed by [BookingModel.fromApiJson]
/// — Task 19.x) and narrows it down to the dashboard's simpler
/// [BookingData].
// ---------------------------------------------------------------------
// Clients — GET /connections (ConnectionRead), reusing
// StudioClientConnection.fromApiJson
// ---------------------------------------------------------------------

/// Wraps a `ConnectionRead` row (already parsed by
/// [StudioClientConnection.fromApiJson] — Task 19.x) and turns it into
/// [ClientData] for the dashboard's Clients list.
class DashboardClientDto {
  final StudioClientConnection connection;

  const DashboardClientDto(this.connection);

  factory DashboardClientDto.fromApiJson(
    Map<String, dynamic> json, {
    required String currentUserId,
  }) =>
      DashboardClientDto(
        StudioClientConnection.fromApiJson(json, currentUserId: currentUserId),
      );

  String get clientId => connection.clientId;

  /// Only `connected` (backend `accepted`) rows count as an actual
  /// client on the dashboard — matches `client_count` in
  /// `AdminDashboardStatsRead`, which only counts accepted connections
  /// too. Pending/declined rows still resolve a name (for booking
  /// lookups — see [DashboardBookingDto.toBookingData]) but shouldn't
  /// show up in the Clients list itself.
  bool get isActiveClient => connection.status == ConnectionStatus.connected;

  String _connectionStatusLabel() {
    switch (connection.status) {
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.pendingStudioRequest:
        return 'Invite Sent';
      case ConnectionStatus.pendingClientRequest:
        return 'Requested to Connect';
      case ConnectionStatus.rejected:
        return 'Declined';
      case ConnectionStatus.blocked:
        return 'Blocked';
      case ConnectionStatus.notConnected:
        return 'Not Connected';
    }
  }

  /// `null` when this connection has no client profile attached at all
  /// (shouldn't happen from the studio's own `GET /connections`, but
  /// [StudioClientConnection.fromApiJson] only populates `clientData`
  /// when the viewer is the studio side, so this stays defensive).
  ///
  /// outstanding balance, paid status, booking value, email,
  /// gallery status, view/download counts, activity log — is left at
  /// [ClientData]'s neutral defaults rather than fabricated, same as
  /// [StudioClientConnection.fromApiJson] already documents for its own
  /// `clientData` field.
  ClientData? toClientData() {
    final base = connection.clientData;
    if (base == null) return null;
    // `bookingStatus` isn't one of `ClientData.copyWith`'s parameters
    // (it's treated as fixed once set elsewhere in the app), so this
    // builds a new instance directly rather than trying to copy it in;
    // everything else comes straight from `base` unchanged.
    return ClientData(
      id: base.id,
      name: base.name,
      initials: base.initials,
      // `StudioClientConnection.fromApiJson` leaves `gradient` as an
      // empty list (it has no color opinion at that layer) — fill in a
      // stable one here, same deterministic-by-id approach as
      // `DashboardUploadsDto`'s album rows.
      gradient: base.gradient.isNotEmpty ? base.gradient : _gradientFor(base.id),
      bookingStatus: _connectionStatusLabel(),
      galleryStatus: base.galleryStatus,
      outstanding: base.outstanding,
      isPaid: base.isPaid,
      bookingValue: base.bookingValue,
      email: base.email,
      lastActive: connection.respondedAt ?? connection.requestedAt,
      assignedGalleryIds: base.assignedGalleryIds,
      totalViews: base.totalViews,
      totalDownloads: base.totalDownloads,
      activityLog: base.activityLog,
    );
  }
}

// ---------------------------------------------------------------------
// Recent uploads — GET /media (MediaRead), reusing MediaModel.fromApiJson
// ---------------------------------------------------------------------

/// Wraps the `/media` list response (already parsed item-by-item by
/// [MediaModel.fromApiJson] — Task 19.x) and groups it into
/// [AlbumUploadData] rows for the dashboard's Recent Uploads section.
///
/// `MediaRead` only carries `album_id`, never an album *name* — there is
/// no `/albums` call in this task's endpoint list (Task 20.6 is scoped
/// to `/admin-dashboard/stats`, `/bookings`, `/connections`, `/media`,
/// `/notifications` only), so [AlbumUploadData.albumName] here is a
/// placeholder built off the id rather than a real name. Wiring in the
/// real name is a follow-up once an albums endpoint is part of this
/// repository's fetch.
class DashboardUploadsDto {
  final List<MediaModel> media;

  const DashboardUploadsDto(this.media);

  factory DashboardUploadsDto.fromApiJson(List<dynamic> json) => DashboardUploadsDto(
        json.map((e) => MediaModel.fromApiJson(e as Map<String, dynamic>)).toList(),
      );

  /// Only used when [albumId] doesn't resolve to a real album — either
  /// the media is unfiled, or (rare) its album was deleted after the
  /// media was uploaded and the row is now orphaned.
  String _placeholderAlbumName(String? albumId) {
    if (albumId == null) return 'Unfiled Uploads';
    final prefix = albumId.length >= 8 ? albumId.substring(0, 8) : albumId;
    return 'Album $prefix';
  }

  /// Groups by `albumId` (nulls grouped together as "unfiled"), newest
  /// group first, capped to [maxGroups] rows — the dashboard only shows
  /// a handful of "recent uploads" cards, not every album ever created.
  /// [mediaCount] on each row only reflects however many items this
  /// `/media` call actually returned (bounded by that call's own
  /// `limit`), not the album's true total — another gap that needs a
  /// dedicated albums/media-count endpoint to close properly.
  ///
  /// [albums], from the same batch of calls fetchSnapshot() already
  /// makes (`GET /albums`), resolves each group to its real name —
  /// falling back to [_placeholderAlbumName] only for the rare group
  /// that doesn't match any album still on file.
  List<AlbumUploadData> toAlbumUploads({
    int maxGroups = 10,
    List<AlbumModel> albums = const [],
  }) {
    final nameById = {for (final a in albums) a.id: a.name};

    final groups = <String, List<MediaModel>>{};
    for (final item in media) {
      final key = item.albumId ?? '__unfiled__';
      groups.putIfAbsent(key, () => []).add(item);
    }

    final rows = groups.entries.map((entry) {
      final key = entry.key;
      final items = entry.value;
      final albumId = key == '__unfiled__' ? null : key;
      final latestItem =
          items.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
      final latest = latestItem.createdAt;
      final allVideo = items.every((m) => m.type == MediaType.video);

      // Prefer a photo's thumbnail for the card cover — a lone video in
      // an otherwise-photo group would show a black/blank frame, and
      // photos are far more likely to have a generated thumbnail_url.
      final coverItem = items.firstWhere(
        (m) => m.type == MediaType.photo,
        orElse: () => latestItem,
      );
      final thumbnailUrl = coverItem.remoteThumbnailUrl?.isNotEmpty == true
          ? coverItem.remoteThumbnailUrl
          : coverItem.remoteUrl;

      return AlbumUploadData(
        id: 'album-$key',
        albumName: (albumId != null ? nameById[albumId] : null) ??
            _placeholderAlbumName(albumId),
        uploadedAgo: relativeTime(latest),
        mediaCount: items.length,
        icon: allVideo ? Icons.movie_creation_rounded : Icons.photo_camera_rounded,
        gradient: _gradientFor(key),
        // A group can be mixed photos+videos; AlbumUploadData.isVideo is
        // a single flag, so a group only reads as "video" when every
        // item in it is a video, and defaults to the photo styling
        // otherwise (a mixed group is treated like a photo album).
        isVideo: allVideo,
        uploadedAt: latest,
        thumbnailUrl: thumbnailUrl,
      );
    }).toList()
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

    return rows.take(maxGroups).toList();
  }
}

// ---------------------------------------------------------------------
// Notifications — GET /notifications (NotificationRead)
// ---------------------------------------------------------------------

/// Parses one `NotificationRead` row for the *studio* Notifications
/// screen's [NotificationData] shape. Distinct from
/// `NotificationsRepository._fromJson` (`repositories/notifications_repository.dart`),
/// which maps the same endpoint onto [NotificationAlert] for the
/// *client* Alerts tab instead — same backend table, two different
/// UI-facing shapes depending on which role is asking.
class DashboardNotificationDto {
  final String id;
  final NotificationType type;
  final String title;
  final String subtitle;
  final DateTime createdAt;
  final bool isRead;

  const DashboardNotificationDto({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.createdAt,
    required this.isRead,
  });

  /// The backend's `NotificationType` has two extra values —
  /// `connection` and `system` — that don't exist in the dashboard's
  /// narrower enum (`reminder`/`approval`/`booking`/`gallery`, see
  /// `models/notification.py`'s docstring). `connection` (a new
  /// invite/accept/decline event) folds onto `approval`, the closest
  /// existing "something needs your attention" bucket; `system` folds
  /// onto `reminder`, the closest generic-FYI bucket.
  static NotificationType _dashboardTypeFrom(String apiType) {
    switch (apiType) {
      case 'reminder':
        return NotificationType.reminder;
      case 'approval':
        return NotificationType.approval;

      case 'gallery':
        return NotificationType.gallery;
      case 'connection':
        return NotificationType.approval;
      case 'system':
      default:
        return NotificationType.reminder;
    }
  }

  factory DashboardNotificationDto.fromApiJson(Map<String, dynamic> json) => DashboardNotificationDto(
        id: json['id'] as String,
        type: _dashboardTypeFrom(json['type'] as String? ?? 'system'),
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
        isRead: json['is_read'] as bool? ?? false,
      );

  NotificationData toNotificationData() => NotificationData(
        id: id,
        type: type,
        title: title,
        subtitle: subtitle,
        createdAt: createdAt,
        isRead: isRead,
      );
}

// ---------------------------------------------------------------------
// Activity Timeline — GET /activity-log (ActivityLogList, Task 20.3),
// reused directly (no richer domain model exists for this one — the
// Recent Activity screen's [ActivityEntry] *is* the API-facing shape).
// ---------------------------------------------------------------------

/// Parses one `ActivityLogRead` row. `ActivityLog.type`
/// (`app/models/activity_log.py`) is documented as mirroring the
/// Flutter [ActivityType] enum name-for-name, so this parses by name
/// rather than a hand-written switch — but still falls back to
/// [ActivityType.report] (the least action-implying bucket) for any
/// value the enum doesn't recognize, rather than throwing and taking
/// the whole dashboard fetch down with it.
class DashboardActivityDto {
  final String id;
  final ActivityType type;
  final String title;
  final String subtitle;
  final DateTime createdAt;

  const DashboardActivityDto({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.createdAt,
  });

  static ActivityType _activityTypeFrom(String apiType) {
    for (final value in ActivityType.values) {
      if (value.name == apiType) return value;
    }
    return ActivityType.report;
  }

  factory DashboardActivityDto.fromApiJson(Map<String, dynamic> json) => DashboardActivityDto(
        id: json['id'] as String,
        type: _activityTypeFrom(json['type'] as String? ?? ''),
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );

  ActivityEntry toActivityEntry() => ActivityEntry(
        id: id,
        type: type,
        title: title,
        subtitle: subtitle,
        timestamp: createdAt,
      );
}

/// Wraps the whole `GET /activity-log` envelope (`{items, total, limit,
/// offset}` — a paginated response, unlike every other endpoint this
/// repository calls) and maps its `items` down to [ActivityEntry] rows,
/// newest first (already the order the backend returns them in).
class DashboardActivityLogDto {
  final List<DashboardActivityDto> items;

  const DashboardActivityLogDto(this.items);

  factory DashboardActivityLogDto.fromApiJson(Map<String, dynamic> json) => DashboardActivityLogDto(
        (json['items'] as List<dynamic>? ?? const [])
            .map((e) => DashboardActivityDto.fromApiJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );

  List<ActivityEntry> toActivityLog() => items.map((dto) => dto.toActivityEntry()).toList(growable: false);
}

// ---------------------------------------------------------------------
// Analytics carousel — GET /admin-dashboard/analytics
// (AdminDashboardAnalyticsRead, Task 20.4)
// ---------------------------------------------------------------------

class DashboardAnalyticsDto {
  const DashboardAnalyticsDto();

  factory DashboardAnalyticsDto.fromApiJson(Map<String, dynamic> json) {
    return const DashboardAnalyticsDto();
  }

  List<AnalyticsSeries> toAnalyticsSeries() => [];
}