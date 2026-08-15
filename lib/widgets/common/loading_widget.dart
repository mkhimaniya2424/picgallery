import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// Shared loading indicator with an optional message, styled to match the
/// Picgallery gradient palette instead of the default Material spinner.
class LoadingWidget extends StatelessWidget {
  final String? message;

  const LoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          shaderCallback: (bounds) =>
              AppColors.heroGradient.createShader(bounds),
          child: const SizedBox(
            width: 34,
            height: 34,
            child:
                CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(message!,
              style: const TextStyle(
                  color: AppColors.subtitle, fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }
}
