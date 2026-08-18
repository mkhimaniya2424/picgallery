import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Service handling media & camera permission checks and user feedback.
///
/// Each method triggers the real native OS permission dialog the first
/// time it's called (via `permission_handler`), and returns the result.
/// If the user already granted/denied it previously, the OS won't show
/// the dialog again — `.request()` just returns the current status.
class PermissionService {
  PermissionService._();

  static final PermissionService instance = PermissionService._();

  /// Requests camera access. Returns true if granted.
  Future<bool> checkAndRequestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Requests photo library / gallery access. Returns true if granted
  /// (including "limited" access on iOS 14+, which still lets the app
  /// read selected photos).
  Future<bool> checkAndRequestStoragePermission() async {
    if (Platform.isAndroid) {
      // Android 13+ (API 33+) split "storage" into typed media
      // permissions; Permission.photos maps to READ_MEDIA_IMAGES there
      // and falls back to READ_EXTERNAL_STORAGE on older Android.
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    }
    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    }
    // Desktop platforms: no OS-level photo permission concept.
    return true;
  }

  /// Requests push notification permission. Returns true if granted.
  Future<bool> checkAndRequestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Current status without prompting — use this to decide whether to
  /// show an explanatory UI before calling `.request()`, or to check
  /// state on screens like App Permissions without re-triggering the
  /// OS dialog.
  Future<bool> isCameraPermissionGranted() async => (await Permission.camera.status).isGranted;

  Future<bool> isStoragePermissionGranted() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final status = await Permission.photos.status;
      return status.isGranted || status.isLimited;
    }
    return true;
  }

  Future<bool> isNotificationPermissionGranted() async => (await Permission.notification.status).isGranted;

  /// True if the user denied a permission with "Don't ask again" /
  /// permanently, meaning `.request()` won't show the OS dialog again
  /// and the only way forward is the device Settings app.
  Future<bool> isPermanentlyDenied(Permission permission) async => (await permission.status).isPermanentlyDenied;

  /// Opens the app's page in the device's Settings app.
  Future<bool> openAppSettingsPage() => openAppSettings();
}
