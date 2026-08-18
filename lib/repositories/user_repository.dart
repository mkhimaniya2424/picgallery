import '../core/network/api_client.dart';
import '../models/user.dart';

/// Wires the `/users/*` FastAPI endpoints (`app/api/routes/users.py`) up
/// to [ApiClient]. Kept separate from [AuthRepository], which covers the
/// distinct `/auth/*` router — same one-repository-per-router-group
/// convention as [LocationRepository].
class UserRepository {
  final ApiClient _apiClient;

  UserRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  /// PATCH /users/me — partial profile update (Task 5). The backend only
  /// changes fields actually present in the request body
  /// (`UserUpdate.model_dump(exclude_unset=True)`), so only the
  /// non-null arguments here are included — passing an explicit `null`
  /// through would tell the backend to clear that field, not leave it
  /// alone.
  Future<AppUser> updateProfile({
    String? fullName,
    String? country,
    String? state,
    String? city,
    String? address,
    String? bio,
    // Studio profile fields (Task 8-9) — meaningful only for photographer
    // accounts; callers should leave these null for client accounts.
    String? studioName,
    String? logoUrl,
    String? coverPhotoUrl,
    List<String>? portfolioImages,
    int? yearEstablished,
    int? teamSize,
    List<String>? serviceAreas,
    List<String>? specializations,
    String? studioType,
    int? experienceYears,
    List<String>? languages,
    String? equipmentHighlights,
    double? pricingMin,
    double? pricingMax,
    String? packageDetails,
    List<String>? availabilityDays,
    String? instagramUrl,
    String? facebookUrl,
    String? youtubeUrl,
    String? pinterestUrl,
    // Client optional profile fields (Task 8) — meaningful only for
    // client accounts; callers should leave these null for photographers.
    String? profilePhotoUrl,
    String? gender,
    DateTime? dateOfBirth,
    List<String>? preferredPhotoTypes,
    String? preferredCity,
    double? budgetMin,
    double? budgetMax,
    // Privacy & Security screen — "Download Permissions" toggle. Shared
    // by both roles.
    bool? allowDownloads,
    // App Settings screen — "App Language" picker. Shared by both roles.
    String? appLanguage,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName;
    if (country != null) body['country'] = country;
    if (state != null) body['state'] = state;
    if (city != null) body['city'] = city;
    if (address != null) body['address'] = address;
    if (bio != null) body['bio'] = bio;

    if (studioName != null) body['studio_name'] = studioName;
    if (logoUrl != null) body['logo_url'] = logoUrl;
    if (coverPhotoUrl != null) body['cover_photo_url'] = coverPhotoUrl;
    if (portfolioImages != null) body['portfolio_images'] = portfolioImages;
    if (yearEstablished != null) body['year_established'] = yearEstablished;
    if (teamSize != null) body['team_size'] = teamSize;
    if (serviceAreas != null) body['service_areas'] = serviceAreas;
    if (specializations != null) body['specializations'] = specializations;
    if (studioType != null) body['studio_type'] = studioType;
    if (experienceYears != null) body['experience_years'] = experienceYears;
    if (languages != null) body['languages'] = languages;
    if (equipmentHighlights != null) body['equipment_highlights'] = equipmentHighlights;
    if (pricingMin != null) body['pricing_min'] = pricingMin;
    if (pricingMax != null) body['pricing_max'] = pricingMax;
    if (packageDetails != null) body['package_details'] = packageDetails;
    if (availabilityDays != null) body['availability_days'] = availabilityDays;
    if (instagramUrl != null) body['instagram_url'] = instagramUrl;
    if (facebookUrl != null) body['facebook_url'] = facebookUrl;
    if (youtubeUrl != null) body['youtube_url'] = youtubeUrl;
    if (pinterestUrl != null) body['pinterest_url'] = pinterestUrl;

    if (profilePhotoUrl != null) body['profile_photo_url'] = profilePhotoUrl;
    if (gender != null) body['gender'] = gender;
    if (dateOfBirth != null) {
      body['date_of_birth'] = dateOfBirth.toIso8601String().split('T').first;
    }
    if (preferredPhotoTypes != null) body['preferred_photo_types'] = preferredPhotoTypes;
    if (preferredCity != null) body['preferred_city'] = preferredCity;
    if (budgetMin != null) body['budget_min'] = budgetMin;
    if (budgetMax != null) body['budget_max'] = budgetMax;
    if (allowDownloads != null) body['allow_downloads'] = allowDownloads;
    if (appLanguage != null) body['app_language'] = appLanguage;

    final json = await _apiClient.patch('/users/me', body: body);
    return AppUser.fromJson(json as Map<String, dynamic>);
  }

  /// DELETE /users/me (Task 10 — Delete Account). [password] confirms
  /// the request for local (email/password) accounts; the backend
  /// ignores it for Google/Apple accounts, which have no password to
  /// check in the first place. Returns the backend's confirmation
  /// message. Soft-deletes server-side — the caller (the Delete Account
  /// screen) is responsible for clearing the local session afterwards
  /// via `AuthNotifier.logout()`, same as any other sign-out.
  Future<String> deleteAccount({String? password}) async {
    final json = await _apiClient.delete(
      '/users/me',
      body: {if (password != null && password.isNotEmpty) 'password': password},
    );
    return (json as Map<String, dynamic>)['message'] as String;
  }
}