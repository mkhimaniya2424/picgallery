import '../core/network/api_client.dart';

/// Wires the `/locations/*` FastAPI endpoints (`app/api/routes/locations.py`)
/// up to [ApiClient] — same one-repository-per-router-group convention as
/// [LegalRepository] / [NotificationsRepository].
///
/// The backend serves the full offline country/state/city dataset (250
/// countries, ~5k states, ~148k cities — see `app/core/location_data.py`).
/// This repository is what [CascadingLocationPicker] should be calling
/// instead of the old hardcoded, only-a-handful-of-cities-per-state map
/// that used to live client-side.
class LocationRepository {
  final ApiClient _apiClient;

  LocationRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  /// GET /locations/countries — all ~250 countries, sorted by name.
  /// Public data, no auth required.
  Future<List<String>> fetchCountries() async {
    final json = await _apiClient.get('/locations/countries', withAuth: false);
    return (json as List)
        .cast<Map<String, dynamic>>()
        .map((c) => c['name'] as String)
        .toList();
  }

  /// GET /locations/states?country=... — states/provinces for a country.
  /// Returns an empty list (rather than throwing) if the backend doesn't
  /// recognize the country name, so callers can fall back to free-text
  /// entry instead of surfacing a raw error.
  Future<List<String>> fetchStates(String country) async {
    try {
      final json = await _apiClient.get(
        '/locations/states?country=${Uri.encodeQueryComponent(country)}',
        withAuth: false,
      );
      return (json as List)
          .cast<Map<String, dynamic>>()
          .map((s) => s['name'] as String)
          .toList();
    } on ApiException catch (e) {
      if (e.statusCode == 404) return const [];
      rethrow;
    }
  }

  /// GET /locations/cities?country=...&state=... — cities for a
  /// country + state pair. Same 404-to-empty-list fallback as
  /// [fetchStates].
  Future<List<String>> fetchCities(String country, String state) async {
    try {
      final json = await _apiClient.get(
        '/locations/cities'
        '?country=${Uri.encodeQueryComponent(country)}'
        '&state=${Uri.encodeQueryComponent(state)}',
        withAuth: false,
      );
      return (json as List)
          .cast<Map<String, dynamic>>()
          .map((c) => c['name'] as String)
          .toList();
    } on ApiException catch (e) {
      if (e.statusCode == 404) return const [];
      rethrow;
    }
  }
}
