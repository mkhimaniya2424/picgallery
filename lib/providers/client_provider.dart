import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/client_model.dart';
import '../repositories/client_repository.dart';
import '../storage/client_local_store.dart';

final clientDirectoryRepositoryProvider =
    Provider<ClientDirectoryRepository>((ref) {
  return LocalClientDirectoryRepository(ClientLocalStore());
});

class ClientNotifier extends ChangeNotifier {
  final Ref ref;
  List<ClientModel> _clients = [];

  ClientNotifier(this.ref) {
    _loadClients();
  }

  ClientDirectoryRepository get _repo =>
      ref.read(clientDirectoryRepositoryProvider);

  Future<void> _loadClients() async {
    final loaded = await _repo.fetchClients();
    _clients = List.from(loaded);
    notifyListeners();
  }

  Future<void> refresh() async {
    await _loadClients();
  }

  Future<void> addClient(ClientModel client) async {
    await _repo.saveClient(client);
    await _loadClients();
  }

  Future<void> clearAll() async {
    await _repo.clear();
    _clients.clear();
    notifyListeners();
  }

  List<ClientModel> get clients => List.unmodifiable(_clients);

  ClientModel? findByEmail(String email) {
    final cleanEmail = email.trim().toLowerCase();
    for (final client in _clients) {
      if (client.email.trim().toLowerCase() == cleanEmail) {
        return client;
      }
    }
    return null;
  }
}

final clientProvider = ChangeNotifierProvider<ClientNotifier>((ref) {
  return ClientNotifier(ref);
});
