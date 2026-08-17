import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_dashboard_repository.dart';
import '../data/api_admin_dashboard_repository.dart';
import '../models/admin_dashboard_data.dart';
import 'auth_providers.dart';

/// Swap this single line to point the whole Admin Dashboard at a real
/// backend later (Django API, Firebase, REST, etc.) — nothing else in
/// the app needs to change since every screen only depends on
/// [AdminDashboardRepository]. Now pointed at [ApiAdminDashboardRepository]
/// (Task 20.6/20.7) — same `currentUserId` callback pattern
/// [studio_client_connections_provider.dart]'s `ApiConnectionsRepository`
/// already uses, so it always reads whoever is currently logged in
/// rather than capturing a stale id at provider-creation time.
final adminDashboardRepositoryProvider = Provider<AdminDashboardRepository>((ref) {
  return ApiAdminDashboardRepository(
    apiClient: ref.watch(apiClientProvider),
    currentUserId: () => ref.read(authStateProvider).user?.id ?? '',
    studioName: () => ref.read(authStateProvider).user?.studioName ?? '',
    photographerName: () => ref.read(authStateProvider).user?.fullName ?? '',
  );
});

/// Async, mutable dashboard state. The screen watches this and reacts to
/// loading / data / error automatically — there is no compile-time data
/// anywhere in the widget tree. Every mutation below re-fetches through
/// the repository, which also persists to on-device storage, so the
/// dashboard survives an app restart.
final adminDashboardProvider =
    AsyncNotifierProvider<AdminDashboardNotifier, AdminDashboardSnapshot>(AdminDashboardNotifier.new);

class AdminDashboardNotifier extends AsyncNotifier<AdminDashboardSnapshot> {
  AdminDashboardRepository get _repo => ref.read(adminDashboardRepositoryProvider);

  @override
  Future<AdminDashboardSnapshot> build() => _repo.fetchSnapshot();

  /// Pull-to-refresh / retry-after-error.
  Future<void> refresh() async {
    state = const AsyncLoading<AdminDashboardSnapshot>().copyWithPrevious(state);
    state = await AsyncValue.guard(_repo.fetchSnapshot);
  }

  Future<void> markNotificationRead(String id) async {
    await _repo.markNotificationRead(id);
    await refresh();
  }

  Future<void> markAllNotificationsRead() async {
    await _repo.markAllNotificationsRead();
    await refresh();
  }

  Future<void> deleteNotification(String id) async {
    await _repo.deleteNotification(id);
    await refresh();
  }



  Future<void> addClient({required String name, required String initials}) async {
    await _repo.addClient(name: name, initials: initials);
    await refresh();
  }

  Future<void> removeClient(String clientId) async {
    await _repo.removeClient(clientId);
    await refresh();
  }

  Future<void> assignGalleriesToClient(String clientId, List<String> galleryIds) async {
    await _repo.assignGalleriesToClient(clientId, galleryIds);
    await refresh();
  }

  Future<void> inviteClient({
    required String name,
    required String email,
    required double bookingValue,
  }) async {
    await _repo.inviteClient(
      name: name,
      email: email,
      bookingValue: bookingValue,
    );
    await refresh();
  }

  Future<void> addUpload({required String albumName, required bool isVideo}) async {
    await _repo.addUpload(albumName: albumName, isVideo: isVideo);
    await refresh();
  }

  Future<void> pushNotification({
    required NotificationType type,
    required String title,
    required String subtitle,
  }) async {
    await _repo.pushNotification(type: type, title: title, subtitle: subtitle);
    await refresh();
  }

  Future<void> shareGallery({required String albumName}) async {
    await _repo.shareGallery(albumName: albumName);
    await refresh();
  }

  /// Returns the generated report summary so the caller can show it
  /// (e.g. in a dialog) immediately, while the dashboard state (and its
  /// new Activity Timeline entry) refreshes underneath.
  Future<String> generateReport() async {
    final summary = await _repo.generateReport();
    await refresh();
    return summary;
  }

  Future<void> resetToSeedData() async {
    await _repo.resetToSeedData();
    await refresh();
  }
}