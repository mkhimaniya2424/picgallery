import 'package:flutter/material.dart';

import 'admin_dashboard_data.dart';

/// Deterministic-by-id placeholder gradient, same idea
/// `DashboardClientDto`/`DashboardUploadsDto` (`admin_dashboard_dto.dart`)
/// already use for rows that have no real gradient opinion of their own.
/// Duplicated here (rather than imported) because that palette is
/// private to `admin_dashboard_dto.dart` and this model has no
/// dependency on the dashboard layer otherwise — kept intentionally
/// small and self-contained.
const List<List<Color>> _kPlaceholderGradients = [
  [Color(0xFF7C5CFF), Color(0xFFA855F7)],
  [Color(0xFFEC4899), Color(0xFFF472B6)],
  [Color(0xFF22C55E), Color(0xFF10B981)],
  [Color(0xFFF59E0B), Color(0xFFEF4444)],
  [Color(0xFF0EA5E9), Color(0xFF3B82F6)],
  [Color(0xFF6366F1), Color(0xFF8B5CF6)],
];

List<Color> _gradientFor(String id) =>
    _kPlaceholderGradients[id.hashCode.abs() % _kPlaceholderGradients.length];

enum ConnectionStatus {
  notConnected,
  pendingClientRequest,
  pendingStudioRequest,
  connected,
  rejected,
  blocked,
}

class StudioClientConnection {
  final String id;
  final String studioId;
  final String clientId;
  final ConnectionStatus status;
  final DateTime requestedAt;
  final DateTime? respondedAt;
  final String initiatedBy; // 'client' or 'studio'
  final ClientData? clientData; // Client profile details for this connection

  StudioClientConnection({
    required this.id,
    required this.studioId,
    required this.clientId,
    required this.status,
    required this.requestedAt,
    this.respondedAt,
    required this.initiatedBy,
    this.clientData,
  });

  StudioClientConnection copyWith({
    String? id,
    String? studioId,
    String? clientId,
    ConnectionStatus? status,
    DateTime? requestedAt,
    DateTime? respondedAt,
    String? initiatedBy,
    ClientData? clientData,
  }) {
    return StudioClientConnection(
      id: id ?? this.id,
      studioId: studioId ?? this.studioId,
      clientId: clientId ?? this.clientId,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      respondedAt: respondedAt ?? this.respondedAt,
      initiatedBy: initiatedBy ?? this.initiatedBy,
      clientData: clientData ?? this.clientData,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'studioId': studioId,
        'clientId': clientId,
        'status': status.name,
        'requestedAt': requestedAt.toIso8601String(),
        'respondedAt': respondedAt?.toIso8601String(),
        'initiatedBy': initiatedBy,
        'clientData': clientData?.toJson(),
      };

  factory StudioClientConnection.fromJson(Map<String, dynamic> json) =>
      StudioClientConnection(
        id: json['id'] as String,
        studioId: json['studioId'] as String,
        clientId: json['clientId'] as String,
        status: ConnectionStatus.values.byName(json['status'] as String),
        requestedAt: DateTime.parse(json['requestedAt'] as String),
        respondedAt: json['respondedAt'] != null
            ? DateTime.parse(json['respondedAt'] as String)
            : null,
        initiatedBy: json['initiatedBy'] as String,
        clientData: json['clientData'] != null
            ? ClientData.fromJson(json['clientData'] as Map<String, dynamic>)
            : null,
      );

  /// Parses one row of the real backend's `GET /connections` /
  /// `POST /connections/invite` / `.../accept` / `.../decline` response
  /// shape (`ConnectionRead` in `app/schemas/connection.py`). Distinct
  /// from [fromJson], which round-trips the local (Hive) persistence
  /// shape instead.
  ///
  /// The API response only nests the *other* party's profile — a
  /// studio viewer gets `client`, a client viewer gets `studio` — so
  /// [currentUserId] (the viewer's own id, from auth state) fills in
  /// whichever side of `studioId`/`clientId` the JSON itself doesn't
  /// carry.
  ///
  /// The backend only tracks three states (`pending`/`accepted`/
  /// `declined`) plus who sent the invite (`initiated_by`); this maps
  /// them onto this model's more granular [ConnectionStatus] the same
  /// way the rest of the app already reads `pendingClientRequest`/
  /// `pendingStudioRequest` as two UI-level views of a single "pending"
  /// state (see `ConnectionsNotifier` in
  /// `studio_client_connections_provider.dart`).
  factory StudioClientConnection.fromApiJson(
    Map<String, dynamic> json, {
    required String currentUserId,
  }) {
    final clientJson = json['client'] as Map<String, dynamic>?;
    final studioJson = json['studio'] as Map<String, dynamic>?;
    final viewerIsStudio = clientJson != null;
    final otherId = viewerIsStudio ? clientJson['id'] as String : studioJson!['id'] as String;
    final initiatedBy = json['initiated_by'] as String;

    return StudioClientConnection(
      id: json['id'] as String,
      studioId: viewerIsStudio ? currentUserId : otherId,
      clientId: viewerIsStudio ? otherId : currentUserId,
      status: _statusFromApi(json['status'] as String, initiatedBy: initiatedBy),
      requestedAt: DateTime.parse(json['requested_at'] as String),
      respondedAt:
          json['responded_at'] != null ? DateTime.parse(json['responded_at'] as String) : null,
      initiatedBy: initiatedBy,
      // Only the other party's *public* profile fields are available
      // here (id/name/avatar/city/bio/...) — nowhere near everything
      // ClientData models (booking status, gallery status, outstanding
      // balance, ...), since those belong to the admin dashboard's
      // booking workflow, not a bare connection. Only what's actually
      // known is filled in; the rest is left at neutral defaults
      // rather than fabricated, and callers that need the full picture
      // should still hit the client's own profile endpoint.
      clientData: ClientData(
        id: viewerIsStudio ? (clientJson['id'] as String) : (studioJson!['id'] as String),
        name: viewerIsStudio
            ? (clientJson['full_name'] as String? ?? '')
            : (studioJson!['business_name'] as String? ?? studioJson['full_name'] as String? ?? ''),
        initials: _initialsFrom(viewerIsStudio
            ? (clientJson['full_name'] as String?)
            : (studioJson!['business_name'] as String? ?? studioJson['full_name'] as String?)),
        gradient: _gradientFor(viewerIsStudio ? (clientJson['id'] as String) : (studioJson!['id'] as String)),
        bookingStatus: '',
        galleryStatus: GalleryStatus.notStarted,
        outstanding: '',
        isPaid: false,
      ),
    );
  }

  static String _initialsFrom(String? name) {
    if (name == null || name.trim().isEmpty) return '';
    return name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
  }

  static ConnectionStatus _statusFromApi(String status, {required String initiatedBy}) {
    switch (status) {
      case 'accepted':
        return ConnectionStatus.connected;
      case 'declined':
        return ConnectionStatus.rejected;
      case 'pending':
        return initiatedBy == 'studio'
            ? ConnectionStatus.pendingStudioRequest
            : ConnectionStatus.pendingClientRequest;
      default:
        return ConnectionStatus.notConnected;
    }
  }
}