import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../widgets/buttons/gradient_button.dart';
import '../../widgets/common/custom_app_bar.dart';
import '../../widgets/common/screen_backdrop.dart';

/// Placeholder Terms of Service / Privacy Policy screen, opened from the
/// consent checkbox on `register_screen.dart` step 3. Pushed as its own
/// route (`AppRoutes.termsPrivacy`) with the standard `_slide` transition
/// so it reads as a dedicated screen rather than a step in the flow —
/// dismissible via the app bar back button or the "I Understand" button.
/// Copy is Lorem-ipsum-style filler only; swap in real legal text later.
class TermsPrivacyScreen extends StatelessWidget {
  const TermsPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Terms & Privacy'),
      body: ScreenBackdrop(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Terms of Service', style: textTheme.headlineLarge),
                      const SizedBox(height: AppSpacing.md),
                      Text(_termsSections[0], style: textTheme.bodyLarge),
                      const SizedBox(height: AppSpacing.md),
                      Text(_termsSections[1], style: textTheme.bodyLarge),
                      const SizedBox(height: AppSpacing.md),
                      Text(_termsSections[2], style: textTheme.bodyLarge),
                      const SizedBox(height: AppSpacing.xl),
                      Text('Privacy Policy', style: textTheme.headlineLarge),
                      const SizedBox(height: AppSpacing.md),
                      Text(_privacySections[0], style: textTheme.bodyLarge),
                      const SizedBox(height: AppSpacing.md),
                      Text(_privacySections[1], style: textTheme.bodyLarge),
                      const SizedBox(height: AppSpacing.md),
                      Text(_privacySections[2], style: textTheme.bodyLarge),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                child: GradientButton(
                  label: 'I Understand',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const List<String> _termsSections = [
  'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod '
      'tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim '
      'veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex '
      'ea commodo consequat.',
  'Duis aute irure dolor in reprehenderit in voluptate velit esse cillum '
      'dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non '
      'proident, sunt in culpa qui officia deserunt mollit anim id est '
      'laborum.',
  'Sed ut perspiciatis unde omnis iste natus error sit voluptatem '
      'accusantium doloremque laudantium, totam rem aperiam eaque ipsa quae '
      'ab illo inventore veritatis et quasi architecto beatae vitae dicta '
      'sunt explicabo.',
];

const List<String> _privacySections = [
  'Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut '
      'fugit, sed quia consequuntur magni dolores eos qui ratione '
      'voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem '
      'ipsum quia dolor sit amet.',
  'Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis '
      'suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur. '
      'Quis autem vel eum iure reprehenderit qui in ea voluptate velit '
      'esse quam nihil molestiae consequatur.',
  'At vero eos et accusamus et iusto odio dignissimos ducimus qui '
      'blanditiis praesentium voluptatum deleniti atque corrupti quos '
      'dolores et quas molestias excepturi sint occaecati cupiditate non '
      'provident.',
];
