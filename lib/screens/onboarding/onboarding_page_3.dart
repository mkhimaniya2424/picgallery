import 'package:flutter/material.dart';

import 'widgets/onboarding_page_content.dart';

/// Onboarding Page 3 — Private Gallery Sharing.
class OnboardingPage3 extends StatelessWidget {
  const OnboardingPage3({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingPageContent(
      icon: Icons.collections_bookmark_rounded,
      title: 'Private Gallery Sharing',
      description:
          'Share albums beautifully with clients through private, password-protected links built just for them.',
    );
  }
}
