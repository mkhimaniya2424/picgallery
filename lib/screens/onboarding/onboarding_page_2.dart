import 'package:flutter/material.dart';

import 'widgets/onboarding_page_content.dart';

/// Onboarding Page 2 — AI Face Recognition.
class OnboardingPage2 extends StatelessWidget {
  const OnboardingPage2({super.key});

  @override
  Widget build(BuildContext context) {
    return const OnboardingPageContent(
      icon: Icons.face_retouching_natural_rounded,
      title: 'AI Face Recognition',
      description:
          'Find every photo of yourself or a loved one instantly — no more endless scrolling through albums.',
    );
  }
}
