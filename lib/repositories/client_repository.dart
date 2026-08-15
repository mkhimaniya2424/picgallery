import '../models/client_model.dart';
import '../storage/client_local_store.dart';

abstract class ClientDirectoryRepository {
  Future<List<ClientModel>> fetchClients();
  Future<void> saveClient(ClientModel client);
  Future<void> clear();
}

class LocalClientDirectoryRepository implements ClientDirectoryRepository {
  final ClientLocalStore _store;
  final List<ClientModel> _clients = [];

  LocalClientDirectoryRepository(this._store);

  @override
  Future<List<ClientModel>> fetchClients() async {
    if (_clients.isEmpty) {
      final loaded = await _store.load();
      _clients.addAll(loaded);
    }
    return List.unmodifiable(_clients);
  }

  @override
  Future<void> saveClient(ClientModel client) async {
    await fetchClients();
    final index = _clients.indexWhere((c) => c.id == client.id);
    if (index != -1) {
      _clients[index] = client;
    } else {
      _clients.add(client);
    }
    await _store.saveAll(_clients);
  }

  @override
  Future<void> clear() async {
    _clients.clear();
    await _store.clear();
  }
}
