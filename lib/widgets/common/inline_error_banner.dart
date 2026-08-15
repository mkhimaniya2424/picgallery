import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// Shared red-tinted inline error banner for the auth flow — wrong
/// credentials on `login_screen.dart`, an already-registered email on
/// `register_screen.dart`, and any future inline auth error — so every
/// error state shares the same look instead of each screen hand-rolling
/// its own `Container`.
///
/// [action] is an optional trailing widget (e.g. a "Log In Instead"
/// `TextButton`) rendered on its own row below the message.
class InlineErrorBanner extends StatelessWidget {
  final String message;
  final Widget? action;

  const InlineErrorBanner({super.key, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: 2),
            Padding(padding: const EdgeInsets.only(left: 30), child: action),
          ],
        ],
      ),
    );
  }
}
