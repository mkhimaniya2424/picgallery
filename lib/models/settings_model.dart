class SettingsModel {
  final String studioName;
  final String photographerName;
  final String email;
  final String studioId;
  final String clientId;
  final bool emailNotifications;
  final bool pushNotifications;
  final bool smsAlerts;
  final bool securityPinEnabled;
  final String securityPin;
  final bool requirePinOnLaunch;
  final bool privateProfile;
  final bool searchEngineIndexing;
  final bool wifiOnlyUploads;
  final String uploadQuality; // "Original", "High"
  final String themeMode; // "Light", "Dark", "System"
  final String language; // "English", "Hindi", "Spanish"

  final String galleryViewMode; // "Grid", "List", "Timeline"

  const SettingsModel({
    this.studioName = '',
    this.photographerName = '',
    this.email = '',
    this.studioId = '',
    this.clientId = '',
    this.emailNotifications = true,
    this.pushNotifications = true,
    this.smsAlerts = false,
    this.securityPinEnabled = false,
    this.securityPin = '',
    this.requirePinOnLaunch = false,
    this.privateProfile = false,
    this.searchEngineIndexing = true,
    this.wifiOnlyUploads = false,
    this.uploadQuality = 'High',
    this.themeMode = 'System',
    this.language = 'English',
    this.galleryViewMode = 'Grid',
  });

  SettingsModel copyWith({
    String? studioName,
    String? photographerName,
    String? email,
    String? studioId,
    String? clientId,
    bool? emailNotifications,
    bool? pushNotifications,
    bool? smsAlerts,
    bool? securityPinEnabled,
    String? securityPin,
    bool? requirePinOnLaunch,
    bool? privateProfile,
    bool? searchEngineIndexing,
    bool? wifiOnlyUploads,
    String? uploadQuality,
    String? themeMode,
    String? language,
    String? galleryViewMode,
  }) => SettingsModel(
    studioName: studioName ?? this.studioName,
    photographerName: photographerName ?? this.photographerName,
    email: email ?? this.email,
    studioId: studioId ?? this.studioId,
    clientId: clientId ?? this.clientId,
    emailNotifications: emailNotifications ?? this.emailNotifications,
    pushNotifications: pushNotifications ?? this.pushNotifications,
    smsAlerts: smsAlerts ?? this.smsAlerts,
    securityPinEnabled: securityPinEnabled ?? this.securityPinEnabled,
    securityPin: securityPin ?? this.securityPin,
    requirePinOnLaunch: requirePinOnLaunch ?? this.requirePinOnLaunch,
    privateProfile: privateProfile ?? this.privateProfile,
    searchEngineIndexing: searchEngineIndexing ?? this.searchEngineIndexing,
    wifiOnlyUploads: wifiOnlyUploads ?? this.wifiOnlyUploads,
    uploadQuality: uploadQuality ?? this.uploadQuality,
    themeMode: themeMode ?? this.themeMode,
    language: language ?? this.language,
    galleryViewMode: galleryViewMode ?? this.galleryViewMode,
  );

  Map<String, dynamic> toJson() => {
    'studioName': studioName,
    'photographerName': photographerName,
    'email': email,
    'studioId': studioId,
    'clientId': clientId,
    'emailNotifications': emailNotifications,
    'pushNotifications': pushNotifications,
    'smsAlerts': smsAlerts,
    'securityPinEnabled': securityPinEnabled,
    'securityPin': securityPin,
    'requirePinOnLaunch': requirePinOnLaunch,
    'privateProfile': privateProfile,
    'searchEngineIndexing': searchEngineIndexing,
    'wifiOnlyUploads': wifiOnlyUploads,
    'uploadQuality': uploadQuality,
    'themeMode': themeMode,
    'language': language,
    'galleryViewMode': galleryViewMode,
  };

  factory SettingsModel.fromJson(Map<String, dynamic> json) => SettingsModel(
    studioName: json['studioName'] as String? ?? 'Studio Gallery',
    photographerName: json['photographerName'] as String? ?? 'Naman Shrivastava',
    email: json['email'] as String? ?? 'naman@example.com',
    studioId: json['studioId'] as String? ?? '',
    clientId: json['clientId'] as String? ?? '',
    emailNotifications: json['emailNotifications'] as bool? ?? true,
    pushNotifications: json['pushNotifications'] as bool? ?? true,
    smsAlerts: json['smsAlerts'] as bool? ?? false,
    securityPinEnabled: json['securityPinEnabled'] as bool? ?? false,
    securityPin: json['securityPin'] as String? ?? '',
    requirePinOnLaunch: json['requirePinOnLaunch'] as bool? ?? false,
    privateProfile: json['privateProfile'] as bool? ?? false,
    searchEngineIndexing: json['searchEngineIndexing'] as bool? ?? true,
    wifiOnlyUploads: json['wifiOnlyUploads'] as bool? ?? false,
    uploadQuality: json['uploadQuality'] as String? ?? 'High',
    themeMode: json['themeMode'] as String? ?? 'System',
    language: json['language'] as String? ?? 'English',
    galleryViewMode: json['galleryViewMode'] as String? ?? 'Grid',
  );
}