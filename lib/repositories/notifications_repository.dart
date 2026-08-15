import '../core/network/api_client.dart';
import '../models/notification_alert.dart';

/// Wires the `/notifications` FastAPI endpoints
/// (`app/api/routes/notifications.py`) up to [ApiClient] — same
/// one-repository-per-router-group convention as [LegalRepository].
/// Replaces [AlertsLocalStore] (Hive-only, no server component) as the
/// data source behind [AlertsController].
///
/// The backend's `Notification` row (type/title/subtitle/data/is_read/
/// created_at) is mapped onto the existing [NotificationAlert] shape
/// (title/message/timestamp/isRead) rather than introducing a new model
/// — every screen already consumes [NotificationAlert], so keeping it
/// meant zero changes to `alerts_screen.dart` / `home_sections.dart`.
class NotificationsRepository {
  final ApiClient _apiClient;

  NotificationsRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  /// GET /notifications
  Future<List<NotificationAlert>> fetchAll() async {
    final json = await _apiClient.get('/notifications');
    return (json as List).cast<Map<String, dynamic>>().map(_fromJson).toList();
  }

  /// POST /notifications/{id}/read
  Future<void> markAsRead(String id) async {
    await _apiClient.post('/notifications/$id/read');
  }

  /// POST /notifications/read-all
  Future<void> markAllAsRead() async {
    await _apiClient.post('/notifications/read-all');
  }

  /// DELETE /notifications/{id}
  Future<void> deleteOne(String id) async {
    await _apiClient.delete('/notifications/$id');
  }

  /// DELETE /notifications
  Future<void> clearAll() async {
    await _apiClient.delete('/notifications');
  }

  NotificationAlert _fromJson(Map<String, dynamic> json) {
    return NotificationAlert(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      message: json['subtitle'] as String? ?? '',
      timestamp: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isRead: json['is_read'] as bool? ?? false,
    );
  }
}
