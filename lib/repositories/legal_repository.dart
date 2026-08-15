import '../core/network/api_client.dart';
import '../screens/legal/help_support/help_support_content.dart';
import '../screens/legal/privacy_policy/privacy_policy_content.dart';
import '../screens/legal/terms_conditions/terms_conditions_content.dart';

/// Wires the `/legal/*` FastAPI endpoints (`app/api/routes/legal.py`) up
/// to [ApiClient] — same one-repository-per-router-group convention as
/// [UserRepository]. Content is static/public (no DB row, no user
/// association), so requests skip the auth header.
class LegalRepository {
  final ApiClient _apiClient;

  LegalRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  /// GET /legal/privacy-policy
  Future<PolicyContent> fetchPrivacyPolicy() async {
    final json = await _apiClient.get('/legal/privacy-policy', withAuth: false);
    return PolicyContent.fromApiJson(json as Map<String, dynamic>);
  }

  /// GET /legal/terms-conditions
  Future<TermsContent> fetchTermsConditions() async {
    final json = await _apiClient.get('/legal/terms-conditions', withAuth: false);
    return TermsContent.fromApiJson(json as Map<String, dynamic>);
  }

  /// GET /legal/help-support
  Future<HelpSupportContent> fetchHelpSupport() async {
    final json = await _apiClient.get('/legal/help-support', withAuth: false);
    return HelpSupportContent.fromApiJson(json as Map<String, dynamic>);
  }
}
