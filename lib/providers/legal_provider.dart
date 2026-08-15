import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart' show apiClientProvider;
import '../repositories/legal_repository.dart';
import '../screens/legal/help_support/help_support_content.dart';
import '../screens/legal/privacy_policy/privacy_policy_content.dart';
import '../screens/legal/terms_conditions/terms_conditions_content.dart';

/// Shares the single app-wide [ApiClient] (see `apiClientProvider` in
/// `auth_providers.dart`) — same pattern as `userRepositoryProvider`.
final legalRepositoryProvider = Provider<LegalRepository>((ref) {
  return LegalRepository(apiClient: ref.watch(apiClientProvider));
});

/// One `FutureProvider` per `/legal/*` endpoint rather than a single
/// combined one, so each screen only depends on (and re-fetches) the
/// content it actually shows — a slow/failed Terms & Conditions request
/// never blocks or errors the Privacy Policy screen, and vice versa.
final privacyPolicyProvider = FutureProvider<PolicyContent>((ref) {
  return ref.watch(legalRepositoryProvider).fetchPrivacyPolicy();
});

final termsConditionsProvider = FutureProvider<TermsContent>((ref) {
  return ref.watch(legalRepositoryProvider).fetchTermsConditions();
});

final helpSupportProvider = FutureProvider<HelpSupportContent>((ref) {
  return ref.watch(legalRepositoryProvider).fetchHelpSupport();
});
