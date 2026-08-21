import '../core/network/api_client.dart';
import '../core/utils/app_exceptions.dart';
import '../models/studio_client_connection_model.dart';
import '../storage/studio_client_connections_local_store.dart';

/// Just enough of a client account to resolve "invite by email" to a
/// real `client_id` before calling [ConnectionsRepository.inviteClient]
/// — result of `GET /connections/lookup-client`.
class ClientLookupResult {
  final String id;
  final String fullName;

  const ClientLookupResult({required this.id, required this.fullName});

  factory ClientLookupResult.fromApiJson(Map<String, dynamic> json) {
    return ClientLookupResult(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
    );
  }
}

/// Result of `POST /connections/invite-by-email` — one of two shapes:
///
/// - `connection` set, `invitedEmail` null: the email matched an
///   existing client account and a real connection was created (or
///   reset to pending), same as the old id-based [ConnectionsRepository.inviteClient].
/// - `connection` null, `invitedEmail` set: no account exists yet for
///   that email. The backend recorded the invite and emailed them a
///   signup link — they'll show up as a pending connection the moment
///   they register with this email, no further action needed here.
class ConnectionInviteByEmailResult {
  final StudioClientConnection? connection;
  final String? invitedEmail;

  const ConnectionInviteByEmailResult({this.connection, this.invitedEmail});

  bool get isPendingSignup => connection == null;
}

abstract class ConnectionsRepository {
  Future<List<StudioClientConnection>> fetchConnections();
  Future<void> saveConnection(StudioClientConnection connection);
  Future<void> removeConnection(String connectionId);
  Future<void> clear();

  /// Studio-only: resolves [email] to an existing client account's id.
  /// Backed by `GET /connections/lookup-client`. Throws
  /// [NotFoundException] if no client account exists for that email —
  /// there's no "create a client" endpoint, so a miss means the studio
  /// needs to ask the client to sign up first.
  ///
  /// Superseded by [inviteByEmail] for the actual "Invite New Client"
  /// flow (which handles the no-account-yet case instead of just
  /// throwing), but kept for any other caller that only needs the
  /// lookup itself.
  Future<ClientLookupResult> lookupClientByEmail(String email);

  /// Studio-only: invite a client to connect by [email], whether or
  /// not they already have a PicGallery client account. Backed by
  /// `POST /connections/invite-by-email`. This is what the "Invite New
  /// Client" form should call.
  Future<ConnectionInviteByEmailResult> inviteByEmail(String email);

  /// Studio-only: invite [clientId] to connect. Backed by
  /// `POST /connections/invite`.
  Future<StudioClientConnection> inviteClient(String clientId);

  /// Accept a pending invitation on [connectionId] — only the invited
  /// side (not whoever sent the invite) may call this. Backed by
  /// `POST /connections/{id}/accept`.
  Future<StudioClientConnection> acceptConnection(String connectionId);

  /// Decline a pending invitation on [connectionId] — only the invited
  /// side may call this. Backed by `POST /connections/{id}/decline`.
  Future<StudioClientConnection> declineConnection(String connectionId);
}

class LocalConnectionsRepository implements ConnectionsRepository {
  final StudioClientConnectionsLocalStore _store;
  final List<StudioClientConnection> _connections = [];

  LocalConnectionsRepository(this._store);

  @override
  Future<List<StudioClientConnection>> fetchConnections() async {
    if (_connections.isEmpty) {
      final loaded = await _store.load();
      _connections.addAll(loaded);
    }
    return List.unmodifiable(_connections);
  }

  @override
  Future<void> saveConnection(StudioClientConnection connection) async {
    await fetchConnections();
    final index = _connections.indexWhere((c) => c.id == connection.id);
    if (index != -1) {
      _connections[index] = connection;
    } else {
      _connections.add(connection);
    }
    await _store.saveAll(_connections);
  }

  @override
  Future<void> removeConnection(String connectionId) async {
    await fetchConnections();
    _connections.removeWhere((c) => c.id == connectionId);
    await _store.saveAll(_connections);
  }

  @override
  Future<void> clear() async {
    _connections.clear();
    await _store.clear();
  }

  // `ConnectionsNotifier` (studio_client_connections_provider.dart) is
  // wired to [ApiConnectionsRepository] below, not this class — this
  // local/demo implementation is kept only to satisfy the
  // [ConnectionsRepository] interface (e.g. for tests or an offline
  // mode), so invite/accept/decline semantics aren't implemented here.
  @override
  Future<ClientLookupResult> lookupClientByEmail(String email) {
    throw UnimplementedError(
      'LocalConnectionsRepository does not implement lookupClientByEmail — '
      'use ApiConnectionsRepository, which ConnectionsNotifier is wired to.',
    );
  }

  @override
  Future<ConnectionInviteByEmailResult> inviteByEmail(String email) {
    throw UnimplementedError(
      'LocalConnectionsRepository does not implement inviteByEmail — '
      'use ApiConnectionsRepository, which ConnectionsNotifier is wired to.',
    );
  }

  @override
  Future<StudioClientConnection> inviteClient(String clientId) {
    throw UnimplementedError(
      'LocalConnectionsRepository does not implement inviteClient — '
      'use ApiConnectionsRepository, which ConnectionsNotifier is wired to.',
    );
  }

  @override
  Future<StudioClientConnection> acceptConnection(String connectionId) {
    throw UnimplementedError(
      'LocalConnectionsRepository does not implement acceptConnection — '
      'use ApiConnectionsRepository, which ConnectionsNotifier is wired to.',
    );
  }

  @override
  Future<StudioClientConnection> declineConnection(String connectionId) {
    throw UnimplementedError(
      'LocalConnectionsRepository does not implement declineConnection — '
      'use ApiConnectionsRepository, which ConnectionsNotifier is wired to.',
    );
  }
}

/// API-backed connections, talking to `app/api/routes/connections.py`
/// (`POST /connections/invite`, `GET /connections`,
/// `POST /connections/{id}/accept`, `POST /connections/{id}/decline`)
/// via [ApiClient] — mirrors [ApiStudioRepository]'s shape in
/// `studio_repository.dart`.
///
/// [currentUserId] is a callback (not a fixed string) so it always
/// reads whatever the current session's id is — needed because the
/// backend's response only nests the *other* party's profile; see
/// `StudioClientConnection.fromApiJson`.
class ApiConnectionsRepository implements ConnectionsRepository {
  ApiConnectionsRepository({
    required ApiClient apiClient,
    required String Function() currentUserId,
  })  : _apiClient = apiClient,
        _currentUserId = currentUserId;

  final ApiClient _apiClient;
  final String Function() _currentUserId;

  @override
  Future<List<StudioClientConnection>> fetchConnections() async {
    final json = await _apiClient.get('/connections');
    final list = json as List<dynamic>;
    final selfId = _currentUserId();
    return list
        .map((e) => StudioClientConnection.fromApiJson(
              e as Map<String, dynamic>,
              currentUserId: selfId,
            ))
        .toList(growable: false);
  }

  // The API has no generic upsert or bulk-clear — every mutation is one
  // of the three purpose-built actions below, each backed by its own
  // endpoint, so these three aren't meant to be called on this class.
  @override
  Future<void> saveConnection(StudioClientConnection connection) {
    throw UnimplementedError(
      'ApiConnectionsRepository has no generic upsert — use inviteClient/'
      'acceptConnection/declineConnection instead, each backed by its own endpoint.',
    );
  }

  @override
  Future<void> removeConnection(String connectionId) async {
    await _apiClient.delete('/connections/$connectionId');
  }

  @override
  Future<void> clear() {
    throw UnimplementedError('ApiConnectionsRepository does not support clearing all connections.');
  }

  @override
  Future<ClientLookupResult> lookupClientByEmail(String email) async {
    try {
      final json = await _apiClient.get(
        '/connections/lookup-client?email=${Uri.encodeQueryComponent(email)}',
      );
      return ClientLookupResult.fromApiJson(json as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        throw NotFoundException('No PicGallery client account found for "$email"');
      }
      rethrow;
    }
  }

  @override
  Future<ConnectionInviteByEmailResult> inviteByEmail(String email) async {
    final json = await _apiClient.post('/connections/invite-by-email', body: {'email': email});
    final map = json as Map<String, dynamic>;
    if (map['status'] == 'connected') {
      return ConnectionInviteByEmailResult(
        connection: StudioClientConnection.fromApiJson(
          map['connection'] as Map<String, dynamic>,
          currentUserId: _currentUserId(),
        ),
      );
    }
    return ConnectionInviteByEmailResult(invitedEmail: map['email'] as String? ?? email);
  }

  @override
  Future<StudioClientConnection> inviteClient(String clientId) async {
    try {
      final json = await _apiClient.post('/connections/invite', body: {'client_id': clientId});
      return StudioClientConnection.fromApiJson(
        json as Map<String, dynamic>,
        currentUserId: _currentUserId(),
      );
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        throw NotFoundException('Client "$clientId" no longer exists');
      }
      rethrow;
    }
  }

  @override
  Future<StudioClientConnection> acceptConnection(String connectionId) async {
    try {
      final json = await _apiClient.post('/connections/$connectionId/accept');
      return StudioClientConnection.fromApiJson(
        json as Map<String, dynamic>,
        currentUserId: _currentUserId(),
      );
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        throw NotFoundException('Connection "$connectionId" no longer exists');
      }
      rethrow;
    }
  }

  @override
  Future<StudioClientConnection> declineConnection(String connectionId) async {
    try {
      final json = await _apiClient.post('/connections/$connectionId/decline');
      return StudioClientConnection.fromApiJson(
        json as Map<String, dynamic>,
        currentUserId: _currentUserId(),
      );
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        throw NotFoundException('Connection "$connectionId" no longer exists');
      }
      rethrow;
    }
  }
}