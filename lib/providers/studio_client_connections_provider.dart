import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/studio_client_connection_model.dart';
import '../repositories/connections_repository.dart';
import 'auth_providers.dart';

/// Talks to the real backend (`app/api/routes/connections.py`) via
/// [ApiConnectionsRepository] — see that class's doc comment for the
/// endpoint mapping. [ConnectionsNotifier] below no longer builds rows
/// itself; every mutation is a request to one of the four endpoints,
/// and [state] reflects whatever the server returns.
final connectionsRepositoryProvider = Provider<ConnectionsRepository>((ref) {
  return ApiConnectionsRepository(
    apiClient: ref.watch(apiClientProvider),
    currentUserId: () => ref.read(authStateProvider).user?.id ?? '',
  );
});

class ConnectionsNotifier extends AsyncNotifier<List<StudioClientConnection>> {
  ConnectionsRepository get _repo => ref.read(connectionsRepositoryProvider);

  @override
  Future<List<StudioClientConnection>> build() async {
    final userId = ref.watch(authProvider.select((a) => a.valueOrNull?.id));
    if (userId == null) {
      return [];
    }
    return await _repo.fetchConnections();
  }

  /// Re-fetches from the server — e.g. pull-to-refresh.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.fetchConnections());
  }

  /// Replaces [connection] in [state] if an entry with the same id
  /// already exists, otherwise appends it. Used after every mutation so
  /// the list reflects the server's response without a full re-fetch.
  void _upsert(StudioClientConnection connection) {
    final current = state.valueOrNull ?? [];
    final index = current.indexWhere((c) => c.id == connection.id);
    if (index == -1) {
      state = AsyncData([...current, connection]);
    } else {
      final copy = [...current];
      copy[index] = connection;
      state = AsyncData(copy);
    }
  }

  List<StudioClientConnection> connectionsForClient(String clientId) {
    return (state.valueOrNull ?? []).where((c) => c.clientId == clientId).toList();
  }

  List<StudioClientConnection> connectionsForStudio(String studioId) {
    return (state.valueOrNull ?? []).where((c) => c.studioId == studioId).toList();
  }

  /// Returns pending requests for a given studio — i.e. connections a
  /// client initiated that the studio hasn't responded to yet.
  List<StudioClientConnection> pendingRequestsForStudio(String studioId) {
    return (state.valueOrNull ?? [])
        .where((c) =>
            c.studioId == studioId &&
            c.status == ConnectionStatus.pendingClientRequest)
        .toList();
  }

  /// Returns connected clients for a given studio.
  List<StudioClientConnection> connectedClientsForStudio(String studioId) {
    return (state.valueOrNull ?? [])
        .where((c) =>
            c.studioId == studioId && c.status == ConnectionStatus.connected)
        .toList();
  }

  /// Studio-only: invite a client to connect by [email], whether or not
  /// they already have a PicGallery client account. Backed by
  /// `POST /connections/invite-by-email`. Returns the resulting
  /// connection if the email matched an existing account (and upserts
  /// it into [state]), or `null` if it didn't — in that case there's
  /// nothing to add to [state] yet, since the connection only becomes
  /// real once that email signs up.
  Future<ConnectionInviteByEmailResult> studioInviteByEmail(String email) async {
    final result = await _repo.inviteByEmail(email);
    if (result.connection != null) {
      _upsert(result.connection!);
    }
    return result;
  }

  /// Studio-only: invite [clientId] to connect. Backed by
  /// `POST /connections/invite`. Re-inviting a client who previously
  /// declined resets that row back to pending server-side rather than
  /// creating a duplicate.
  Future<void> studioInviteClient(String clientId) async {
    final connection = await _repo.inviteClient(clientId);
    _upsert(connection);
  }

  /// Accepts a pending connection — works for either direction (a
  /// client-initiated request the studio is approving, or a
  /// studio-initiated invite the client is approving), since
  /// `POST /connections/{id}/accept` only cares that the caller is the
  /// *recipient*, not who initiated it.
  Future<void> _accept(String id) async {
    final connection = await _repo.acceptConnection(id);
    _upsert(connection);
  }

  /// Declines a pending connection — same "works for either direction"
  /// reasoning as [_accept]. Backed by `POST /connections/{id}/decline`.
  Future<void> _decline(String id) async {
    final connection = await _repo.declineConnection(id);
    _upsert(connection);
  }

  /// Removes an accepted connection from the server and local state.
  Future<void> disconnect(String id) async {
    await _repo.removeConnection(id);
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((c) => c.id != id).toList());
  }

  /// Studio approves a client-initiated connection request.
  Future<void> studioAcceptRequest(String id) => _accept(id);

  /// Studio declines a client-initiated connection request.
  Future<void> studioRejectRequest(String id) => _decline(id);

  /// Client accepts a studio-initiated invitation.
  Future<void> clientAcceptInvite(String id) => _accept(id);

  /// Client declines a studio-initiated invitation.
  Future<void> clientDeclineInvite(String id) => _decline(id);
}

final connectionsProvider =
    AsyncNotifierProvider<ConnectionsNotifier, List<StudioClientConnection>>(
  ConnectionsNotifier.new,
);
