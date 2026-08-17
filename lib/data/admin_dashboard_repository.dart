import '../models/admin_dashboard_data.dart';

/// Contract the Admin Dashboard is coded against. The UI never touches
/// concrete data — only this interface, via the provider layer. Today
/// [ApiAdminDashboardRepository] backs it with the studio's real data
/// over HTTP, wired in `adminDashboardRepositoryProvider`. Swapping to a
/// different backend later means writing one new class that implements
/// this and pointing that provider at it — no screen or widget changes.
abstract class AdminDashboardRepository {
  Future<AdminDashboardSnapshot> fetchSnapshot();

  Future<void> markNotificationRead(String notificationId);
  Future<void> markAllNotificationsRead();
  Future<void> deleteNotification(String notificationId);



  Future<ClientData> addClient({required String name, required String initials});
  Future<void> removeClient(String clientId);
  Future<void> assignGalleriesToClient(String clientId, List<String> galleryIds);
  Future<ClientData> inviteClient({
    required String name,
    required String email,
    required double bookingValue,
  });

  Future<AlbumUploadData> addUpload({required String albumName, required bool isVideo});

  Future<NotificationData> pushNotification({
    required NotificationType type,
    required String title,
    required String subtitle,
  });

  Future<void> shareGallery({required String albumName});

  /// Recomputes every headline number off the live data and drops one
  /// "report generated" entry into the Activity Timeline. Returns a
  /// human-readable summary the UI can show immediately.
  Future<String> generateReport();

  /// Clears all in-memory state for the current session, back to a
  /// clean empty dashboard (no seed/demo data is ever restored).
  Future<void> resetToSeedData();
}
