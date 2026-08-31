import 'package:flutter/material.dart';

/// Data shapes for the Photographer/Studio Admin Dashboard.
///
/// The dashboard is fully dynamic: it gets everything through
/// `AdminDashboardRepository` (see lib/data/admin_dashboard_repository.dart),
/// exposed to the UI via Riverpod in
/// lib/providers/admin_dashboard_providers.dart. Only type definitions
/// (and their JSON (de)serialization, used for on-device persistence via
/// lib/storage/dashboard_local_store.dart) live here.

enum TrendDirection { up, down }

class StatCardData {
  final String label;
  final String value;
  final IconData icon;
  final List<Color> gradient;
  final List<double> sparkline;
  final String delta;
  final TrendDirection trend;

  const StatCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
    required this.sparkline,
    required this.delta,
    required this.trend,
  });
}

class QuickActionData {
  final String id;
  final String label;
  final IconData icon;
  final List<Color> gradient;

  const QuickActionData({
    required this.id,
    required this.label,
    required this.icon,
    required this.gradient,
  });
}



class AlbumUploadData {
  final String id;
  final String albumName;
  final String? albumId;
  final String uploadedAgo;
  final int mediaCount;
  final IconData icon;
  final List<Color> gradient;
  final bool isVideo;
  final DateTime uploadedAt;

  /// Fetchable `http(s)://` URL for a representative thumbnail of this
  /// group (the most recently uploaded item's `thumbnail_url`, falling
  /// back to its `file_url`). Null/empty when the backend hasn't
  /// produced one yet (e.g. a video with no generated thumbnail) — the
  /// UI should fall back to the gradient + icon placeholder.
  final String? thumbnailUrl;

  const AlbumUploadData({
    required this.id,
    required this.albumName,
    this.albumId,
    required this.uploadedAgo,
    required this.mediaCount,
    required this.icon,
    required this.gradient,
    required this.uploadedAt,
    this.isVideo = false,
    this.thumbnailUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'albumName': albumName,
        'albumId': albumId,
        'mediaCount': mediaCount,
        'iconCodePoint': icon.codePoint,
        'gradient': gradient.map((c) => c.toARGB32()).toList(),
        'isVideo': isVideo,
        'uploadedAt': uploadedAt.toIso8601String(),
        'thumbnailUrl': thumbnailUrl,
      };

  factory AlbumUploadData.fromJson(Map<String, dynamic> json) => AlbumUploadData(
        id: json['id'] as String,
        albumName: json['albumName'] as String,
        albumId: json['albumId'] as String?,
        uploadedAgo: relativeTime(DateTime.tryParse(json['uploadedAt'] as String? ?? '') ?? DateTime.now()),
        mediaCount: json['mediaCount'] as int,
        // ignore: non_constant_identifier_names
        icon: (json['isVideo'] as bool? ?? false) ? Icons.movie_creation_rounded : Icons.photo_camera_rounded,
        gradient: (json['gradient'] as List).map((v) => Color(v as int)).toList(),
        isVideo: json['isVideo'] as bool? ?? false,
        uploadedAt: DateTime.tryParse(json['uploadedAt'] as String? ?? '') ?? DateTime.now(),
        thumbnailUrl: json['thumbnailUrl'] as String?,
      );
}

enum GalleryStatus { delivered, editing, notStarted }

class ClientData {
  final String id;
  final String name;
  final String initials;
  final List<Color> gradient;
  final String bookingStatus;
  final GalleryStatus galleryStatus;
  final String outstanding;
  final bool isPaid;
  final double bookingValue;
  final String email;
  final DateTime? lastActive;
  final List<String> assignedGalleryIds;
  final int totalViews;
  final int totalDownloads;
  final List<String> activityLog;

  const ClientData({
    required this.id,
    required this.name,
    required this.initials,
    required this.gradient,
    required this.bookingStatus,
    required this.galleryStatus,
    required this.outstanding,
    required this.isPaid,
    this.bookingValue = 0,
    this.email = '',
    this.lastActive,
    this.assignedGalleryIds = const [],
    this.totalViews = 0,
    this.totalDownloads = 0,
    this.activityLog = const [],
  });

  ClientData copyWith({
    bool? isPaid,
    String? outstanding,
    GalleryStatus? galleryStatus,
    String? email,
    DateTime? lastActive,
    List<String>? assignedGalleryIds,
    int? totalViews,
    int? totalDownloads,
    double? bookingValue,
    List<String>? activityLog,
  }) => ClientData(
        id: id,
        name: name,
        initials: initials,
        gradient: gradient,
        bookingStatus: bookingStatus,
        galleryStatus: galleryStatus ?? this.galleryStatus,
        outstanding: outstanding ?? this.outstanding,
        isPaid: isPaid ?? this.isPaid,
        bookingValue: bookingValue ?? this.bookingValue,
        email: email ?? this.email,
        lastActive: lastActive ?? this.lastActive,
        assignedGalleryIds: assignedGalleryIds ?? this.assignedGalleryIds,
        totalViews: totalViews ?? this.totalViews,
        totalDownloads: totalDownloads ?? this.totalDownloads,
        activityLog: activityLog ?? this.activityLog,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'initials': initials,
        'gradient': gradient.map((c) => c.toARGB32()).toList(),
        'bookingStatus': bookingStatus,
        'galleryStatus': galleryStatus.name,
        'outstanding': outstanding,
        'isPaid': isPaid,
        'bookingValue': bookingValue,
        'email': email,
        'lastActive': lastActive?.toIso8601String(),
        'assignedGalleryIds': assignedGalleryIds,
        'totalViews': totalViews,
        'totalDownloads': totalDownloads,
        'activityLog': activityLog,
      };

  factory ClientData.fromJson(Map<String, dynamic> json) => ClientData(
        id: json['id'] as String,
        name: json['name'] as String,
        initials: json['initials'] as String,
        gradient: (json['gradient'] as List).map((v) => Color(v as int)).toList(),
        bookingStatus: json['bookingStatus'] as String,
        galleryStatus: GalleryStatus.values.byName(json['galleryStatus'] as String),
        outstanding: json['outstanding'] as String,
        isPaid: json['isPaid'] as bool,
        bookingValue: (json['bookingValue'] as num?)?.toDouble() ?? 0,
        email: json['email'] as String? ?? '',
        lastActive: json['lastActive'] != null ? DateTime.tryParse(json['lastActive'] as String) : null,
        assignedGalleryIds: (json['assignedGalleryIds'] as List?)?.cast<String>() ?? const [],
        totalViews: json['totalViews'] as int? ?? 0,
        totalDownloads: json['totalDownloads'] as int? ?? 0,
        activityLog: (json['activityLog'] as List?)?.cast<String>() ?? const [],
      );
}

enum NotificationType { reminder, approval, gallery }

class NotificationData {
  final String id;
  final NotificationType type;
  final String title;
  final String subtitle;
  final DateTime createdAt;
  final bool isRead;

  const NotificationData({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.createdAt,
    this.isRead = false,
  });

  String get time => relativeTime(createdAt);

  NotificationData copyWith({bool? isRead}) => NotificationData(
        id: id,
        type: type,
        title: title,
        subtitle: subtitle,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'subtitle': subtitle,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
      };

  factory NotificationData.fromJson(Map<String, dynamic> json) => NotificationData(
        id: json['id'] as String,
        type: NotificationType.values.byName(json['type'] as String),
        title: json['title'] as String,
        subtitle: json['subtitle'] as String,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        isRead: json['isRead'] as bool? ?? false,
      );
}

/// One row in the Activity Timeline — an automatically generated log of
/// every meaningful mutation (upload, album, client, booking, gallery
/// share, profile update...), newest first.
enum ActivityType { upload, album, client, gallery, profile, qr, report }

class ActivityEntry {
  final String id;
  final ActivityType type;
  final String title;
  final String subtitle;
  final DateTime timestamp;

  const ActivityEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
  });

  String get time => relativeTime(timestamp);

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'subtitle': subtitle,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ActivityEntry.fromJson(Map<String, dynamic> json) => ActivityEntry(
        id: json['id'] as String,
        type: ActivityType.values.byName(json['type'] as String),
        title: json['title'] as String,
        subtitle: json['subtitle'] as String,
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      );

  (IconData, List<Color>) get style {
    switch (type) {
      case ActivityType.upload:
        return (Icons.cloud_upload_rounded, const [Color(0xFF7C5CFF), Color(0xFFA855F7)]);
      case ActivityType.album:
        return (Icons.create_new_folder_rounded, const [Color(0xFFEC4899), Color(0xFFF472B6)]);
      case ActivityType.client:
        return (Icons.person_add_alt_1_rounded, const [Color(0xFF7C5CFF), Color(0xFFEC4899)]);

      case ActivityType.gallery:
        return (Icons.ios_share_rounded, const [Color(0xFFA855F7), Color(0xFFEC4899)]);
      case ActivityType.profile:
        return (Icons.person_rounded, const [Color(0xFFF59E0B), Color(0xFFEC4899)]);
      case ActivityType.qr:
        return (Icons.qr_code_scanner_rounded, const [Color(0xFFF59E0B), Color(0xFF7C5CFF)]);
      case ActivityType.report:
        return (Icons.insert_chart_rounded, const [Color(0xFFA855F7), Color(0xFF7C5CFF)]);
    }
  }
}

class AnalyticsSeries {
  final String title;
  final String subtitle;
  final List<double> values;
  final List<Color> gradient;
  final bool isBar;

  const AnalyticsSeries({
    required this.title,
    required this.subtitle,
    required this.values,
    required this.gradient,
    this.isBar = false,
  });
}

/// Everything the dashboard screen needs for one render pass. The
/// repository builds and returns this; nothing in the UI layer hardcodes
/// its contents.
class AdminDashboardSnapshot {
  final String studioName;
  final String photographerName;
  final List<StatCardData> stats;
  final List<QuickActionData> quickActions;

  final List<AlbumUploadData> recentUploads;
  final List<ClientData> clients;
  final List<AnalyticsSeries> analytics;
  final List<NotificationData> notifications;
  final List<ActivityEntry> activityLog;
  final int sharedGalleryCount;
  /// Studio-wide total gallery views (sum of ShareLink.views_count).
  final int totalGalleryViews;
  /// Studio-wide total gallery downloads (count of DownloadEvent rows).
  final int totalGalleryDownloads;

  const AdminDashboardSnapshot({
    required this.studioName,
    required this.photographerName,
    required this.stats,

    required this.quickActions,
    required this.recentUploads,
    required this.clients,
    required this.analytics,
    required this.notifications,
    this.activityLog = const [],
    this.sharedGalleryCount = 0,
    this.totalGalleryViews = 0,
    this.totalGalleryDownloads = 0,
  });

  int get unreadNotificationCount => notifications.where((n) => !n.isRead).length;



  int get pendingDeliveriesCount =>
      clients.where((c) => c.galleryStatus != GalleryStatus.delivered).length;

  AdminDashboardSnapshot copyWith({
    String? studioName,
    String? photographerName,
    List<StatCardData>? stats,
    List<QuickActionData>? quickActions,

    List<AlbumUploadData>? recentUploads,
    List<ClientData>? clients,
    List<AnalyticsSeries>? analytics,
    List<NotificationData>? notifications,
    List<ActivityEntry>? activityLog,
    int? sharedGalleryCount,
    int? totalGalleryViews,
    int? totalGalleryDownloads,
  }) {
    return AdminDashboardSnapshot(
      studioName: studioName ?? this.studioName,
      photographerName: photographerName ?? this.photographerName,
      stats: stats ?? this.stats,

      quickActions: quickActions ?? this.quickActions,
      recentUploads: recentUploads ?? this.recentUploads,
      clients: clients ?? this.clients,
      analytics: analytics ?? this.analytics,
      notifications: notifications ?? this.notifications,
      activityLog: activityLog ?? this.activityLog,
      sharedGalleryCount: sharedGalleryCount ?? this.sharedGalleryCount,
      totalGalleryViews: totalGalleryViews ?? this.totalGalleryViews,
      totalGalleryDownloads: totalGalleryDownloads ?? this.totalGalleryDownloads,
    );
  }
}

/// Shared helper: turns a [DateTime] into a short "5m", "2h", "Yesterday"
/// style relative label — used everywhere a persisted timestamp needs to
/// be redisplayed after an app restart (uploads, notifications, activity).
String relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${time.day}/${time.month}/${time.year}';
}