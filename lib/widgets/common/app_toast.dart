import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// Lightweight, non-blocking notification — the "quick confirmation"
/// counterpart to [AppPopup]'s blocking modal. Used for transient
/// messages that don't need a tap to dismiss (resend confirmations,
/// quick-action feedback, "coming soon" notes) instead of Flutter's
/// stock full-width dark [SnackBar].
///
/// Still built on [SnackBar] under the hood (so it gets the same
/// queueing/auto-dismiss behavior for free), just with fully custom,
/// on-brand content: a floating rounded card, colored icon badge, and
/// transparent stock chrome.
class AppToast {
  static void show(BuildContext context, String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
        padding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: (isError ? AppColors.error : AppColors.primary).withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, 10)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient: isError
                      ? LinearGradient(colors: [AppColors.error.withValues(alpha: 0.85), AppColors.error])
                      : AppColors.buttonGradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
