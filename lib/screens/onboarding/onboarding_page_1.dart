import 'package:flutter/material.dart';

import 'widgets/onboarding_page_content.dart';

/// Onboarding Page 1 — Secure Cloud Storage.
class OnboardingPage1 extends StatelessWidget {
  const OnboardingPage1({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingPageContent(
      icon: Icons.cloud_done_rounded,
      title: 'Secure Cloud Storage',
      description:
          'Store unlimited photos and videos securely, backed up automatically the moment you upload.',
    );
  }
}
