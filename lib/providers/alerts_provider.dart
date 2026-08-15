import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notification_alert.dart';
import '../repositories/notifications_repository.dart';
import 'auth_providers.dart';

/// Provider for the API-backed notifications repository — same
/// `ApiClient`-wired-repository convention as `chatRepositoryProvider`
/// / `albumRepositoryProvider`.
final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(apiClient: ref.watch(apiClientProvider));
});

/// Backs the Client "Alerts" tab. Previously read/wrote
/// [AlertsLocalStore] (Hive-only, no server component); now sources
/// from `GET /notifications` via [NotificationsRepository], the same
/// backend rows the Studio Notifications screen already reads
/// (`ApiAdminDashboardRepository`) — so a connection request/invite/
/// acceptance now shows up here too instead of only arriving by email.
class AlertsController extends ChangeNotifier {
  AlertsController({required this.repository});

  final NotificationsRepository repository;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  final List<NotificationAlert> _items = [];

  List<NotificationAlert> get items => List.unmodifiable(
        [..._items]..sort((a, b) => b.timestamp.compareTo(a.timestamp)),
      );

  int get unreadCount => _items.where((a) => !a.isRead).length;

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      final loaded = await repository.fetchAll();
      _items
        ..clear()
        ..addAll(loaded);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();

  Future<void> markAsRead(String id) async {
    final idx = _items.indexWhere((a) => a.id == id);
    if (idx == -1 || _items[idx].isRead) return;

    // Optimistic update, mirrored to the server; roll back on failure
    // rather than leaving the badge/tile out of sync with the backend.
    final previous = _items[idx];
    _items[idx] = previous.copyWith(isRead: true);
    notifyListeners();

    try {
      await repository.markAsRead(id);
    } catch (_) {
      _items[idx] = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> markAllAsRead() async {
    final previous = List<NotificationAlert>.from(_items);
    var changed = false;
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].isRead) {
        _items[i] = _items[i].copyWith(isRead: true);
        changed = true;
      }
    }
    if (!changed) return;
    notifyListeners();

    try {
      await repository.markAllAsRead();
    } catch (_) {
      _items
        ..clear()
        ..addAll(previous);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteOne(String id) async {
    final idx = _items.indexWhere((a) => a.id == id);
    if (idx == -1) return;

    final removed = _items[idx];
    _items.removeAt(idx);
    notifyListeners();

    try {
      await repository.deleteOne(id);
    } catch (_) {
      _items.insert(idx, removed);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> clearAll() async {
    final previous = List<NotificationAlert>.from(_items);
    _items.clear();
    notifyListeners();

    try {
      await repository.clearAll();
    } catch (_) {
      _items
        ..clear()
        ..addAll(previous);
      notifyListeners();
      rethrow;
    }
  }
}

final alertsProvider = ChangeNotifierProvider<AlertsController>((ref) {
  final repository = ref.watch(notificationsRepositoryProvider);
  final controller = AlertsController(repository: repository);
  // Load eagerly.
  Future.microtask(controller.load);
  return controller;
});