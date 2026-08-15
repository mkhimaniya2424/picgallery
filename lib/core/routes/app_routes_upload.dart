import 'package:flutter/material.dart';

import '../../upload/upload_queue_screen.dart';

/// Kept separate from [app_routes.dart] to avoid touching the existing
/// route table more than necessary.
///
/// Milestone 2 uses a single extra route name for the in-memory upload queue.
@Deprecated(
    'Upload route is now integrated in AppRoutes as AppRoutes.uploadQueue')
class AppRoutesUpload {
  AppRoutesUpload._();

  /// Deprecated: kept only for backwards compilation safety.
  /// Prefer [AppRoutes.uploadQueue].
  static const String uploadQueue = '/upload-queue';

  static Route<dynamic> onGenerateUploadRoute(RouteSettings settings) {
    switch (settings.name) {
      case uploadQueue:
        return _fade(const UploadQueueScreen());
      default:
        return _fade(const UploadQueueScreen());
    }
  }

  static Route<dynamic> _fade(Widget child) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => child,
      transitionsBuilder: (_, animation, __, c) =>
          FadeTransition(opacity: animation, child: c),
      transitionDuration: const Duration(milliseconds: 350),
    );
  }
}
