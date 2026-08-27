import 'dart:io';
import 'package:flutter/material.dart';

import '../../screens/splash/splash_screen.dart';
import '../../screens/onboarding/onboarding_screen.dart';
import '../../screens/auth/role_selection_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/auth/check_email_screen.dart';
import '../../screens/auth/reset_password_screen.dart';
import '../../screens/auth/reset_success_screen.dart';
import '../../screens/auth/email_verification_screen.dart';
import '../../screens/auth/verification_pending_screen.dart';
import '../../screens/auth/otp_verification_screen.dart';
import '../../screens/auth/complete_profile_screen.dart';
import '../../screens/auth/terms_privacy_screen.dart';
import '../../screens/onboarding/camera_permission_screen.dart';
import '../../screens/onboarding/photo_library_permission_screen.dart';
import '../../screens/onboarding/push_notification_permission_screen.dart';
import '../../screens/client/main_nav_screen.dart';
import '../../screens/admin/admin_main_nav_screen.dart';
import '../../screens/shared/edit_profile_screen.dart';
import '../../screens/shared/delete_account_screen.dart';
import '../../screens/shared/app_permissions_screen.dart';
import '../../screens/shared/pin_unlock_screen.dart';

import '../../screens/admin/client_details_screen.dart';
import '../../screens/admin/admin_analytics_screen.dart';
import '../../screens/admin/admin_settings_screen.dart';
import '../../screens/media/trash_screen.dart';
import '../../screens/admin/notifications_screen.dart';
import '../../screens/admin/notification_detail_screen.dart';
import '../../screens/admin/search_screen.dart';
import '../../screens/admin/search_results_screen.dart';
import '../../screens/admin/storage_overview_screen.dart';
import '../../screens/admin/recent_activity_screen.dart';
import '../../screens/admin/quick_actions_screen.dart';
import '../../models/admin_dashboard_data.dart';
import '../../screens/albums/create_album_screen.dart';
import '../../screens/albums/album_details_screen.dart';
import '../../screens/albums/edit_album_screen.dart';
import '../../screens/folders/folder_list_screen.dart';
import '../../screens/folders/create_folder_screen.dart';
import '../../screens/folders/folder_details_screen.dart';
import '../../screens/folders/rename_folder_screen.dart';
import '../../screens/folders/move_folder_screen.dart';
import '../../screens/folders/folder_settings_screen.dart';
import '../../screens/media/media_grid_screen.dart';
import '../../screens/media/media_favorites_screen.dart';
import '../../screens/media/media_search_screen.dart';
import '../../screens/media/media_filter_screen.dart';
import '../../screens/media/video_grid_screen.dart';
import '../../screens/media/media_details_screen.dart';
import '../../screens/media/image_viewer_screen.dart';
import '../../screens/media/video_player_screen.dart';
import '../../screens/media/photo_editor_screen.dart';
import '../../upload/upload_queue_screen.dart';
import '../../screens/albums/share_settings_screen.dart';
import '../../screens/client/shared_gallery_screen.dart';
import '../../screens/client/chat_thread_screen.dart';
import '../../screens/client/discover_studios_screen.dart';
import '../../screens/client/studio_profile_screen.dart';
import '../../screens/client/favorite_studios_screen.dart';
import '../../screens/client/shared_studios_screen.dart';
import '../../screens/client/studio_shared_folders_screen.dart';
import '../../screens/albums/collections_screen.dart';
import '../../screens/albums/collection_details_screen.dart';
import '../../screens/download_history/download_history_screen.dart';
import '../../screens/client/invitations_screen.dart';
import '../../screens/client/profile_settings/privacy_settings_screen.dart';
import '../../screens/client/profile_settings/about_screen.dart';
import '../../screens/media/face_search_landing_screen.dart';
import '../../screens/media/face_search_upload_screen.dart';
import '../../screens/media/face_search_scan_progress_screen.dart';
import '../../screens/media/face_search_results_screen.dart';
import '../../screens/legal/privacy_policy/privacy_policy_screen.dart';
import '../../screens/legal/terms_conditions/terms_conditions_screen.dart';
import '../../screens/legal/help_support/help_support_screen.dart';
import '../../screens/subscription/subscription_plans_screen.dart';


/// User-facing role picked on [RoleSelectionScreen]. Carried through
/// Register / Complete Profile via route arguments so those screens can
/// tailor themselves (e.g. Studio fields for Photographer).
enum UserRole { photographer, client }

class PhotoEditorArgs {
  final dynamic media;
  const PhotoEditorArgs({required this.media});
}

/// Arguments for [AppRoutes.sharedGallery].
class SharedGalleryArgs {
  final String token;
  final bool isPreview;
  const SharedGalleryArgs({required this.token, this.isPreview = false});
}

/// Arguments for [AppRoutes.pinUnlock] — see splash_screen.dart, the only
/// place this route is pushed from. [destinationRoute] is whichever route
/// splash would have gone to directly had the PIN gate not been enabled
/// (Onboarding or Role Selection) — [PinUnlockScreen] pushes it itself
/// once the PIN matches, using its own (still-mounted) context rather
/// than one captured from the splash screen that pushed it.
class PinUnlockArgs {
  final String correctPin;
  final String destinationRoute;
  /// Arguments [destinationRoute] itself needs once the PIN is entered
  /// correctly (e.g. the `UserRole` a completeProfile route requires, or
  /// the `{email, role}` map a verificationPending route requires) — see
  /// splash_screen.dart's `_resolveDestination`, the only place that
  /// builds one of these. Without this, any destination that needs
  /// arguments would silently get called with none once the PIN gate is
  /// in the way, since PinUnlockScreen pushes destinationRoute itself.
  final Object? destinationArguments;
  const PinUnlockArgs({
    required this.correctPin,
    required this.destinationRoute,
    this.destinationArguments,
  });
}

/// Lets a screen (e.g. [MediaGridScreen]) know when it has become visible
/// again after a route pushed on top of it was popped.
final routeObserver = RouteObserver<ModalRoute<void>>();

/// Centralized named-route table for the whole app: the real auth flow
/// (Splash → Onboarding → Role Selection → Login → Register → Forgot
/// Password → Email/OTP Verification → Complete Profile → Home) wired to
/// the real backend, plus the local-only media/albums/folders/search/
/// notifications/upload-queue feature set.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String pinUnlock = '/pin-unlock';
  static const String onboarding = '/onboarding';
  static const String roleSelection = '/role-selection';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String checkEmail = '/check-email';
  static const String resetPassword = '/reset-password';
  static const String resetSuccess = '/reset-success';
  static const String emailVerification = '/email-verification';
  static const String verificationPending = '/verification-pending';
  static const String otpVerification = '/otp-verification';
  static const String completeProfile = '/complete-profile';
  static const String termsPrivacy = '/terms-privacy';
  static const String cameraPermission = '/camera-permission';
  static const String photoLibraryPermission = '/photo-library-permission';
  static const String pushNotificationPermission = '/push-notification-permission';
  static const String home = '/home';
  static const String adminHome = '/admin-home';
  static const String editProfile = '/edit-profile';
  static const String deleteAccount = '/delete-account';
  static const String permissions = '/permissions';

  // Collections
  static const String collections = '/collections';
  static const String collectionsDetails = '/collections/details';

  // Download History (client profile)
  static const String downloadHistory = '/download-history';

  // Client-side studio invitations (accept/decline pending studio invites)
  static const String invitations = '/invitations';

  // Client profile settings sub-screens
  static const String profilePrivacySettings = '/profile/privacy';
  static const String profileAbout = '/profile/about';

  static const String notifications = '/notifications';
  static const String notificationDetail = '/notification-detail';
  static const String search = '/search';
  static const String searchResults = '/search-results';
  static const String storageOverview = '/storage-overview';
  static const String recentActivity = '/recent-activity';
  static const String quickActions = '/quick-actions';

  static const String faceSearchLanding = '/face-search';
  static const String faceSearchUpload = '/face-search/upload';
  static const String faceSearchScanProgressPlaceholder = '/face-search/scan-progress';
  static const String faceSearchResults = '/face-search/results';

  static const String uploadQueue = '/upload-queue';

  static const String media = '/media';
  static const String mediaFavorites = '/media/favorites';
  static const String mediaSearch = '/media/search';
  static const String mediaFilter = '/media/filter';
  static const String videoGrid = '/media/videos';
  static const String mediaDetails = '/media/details';
  static const String imageViewer = '/media/viewer';
  static const String videoPlayer = '/media/video-player';
  static const String photoEditor = '/media/photo-editor';

  static const String adminAlbumCreate = '/admin/albums/create';
  static const String adminAlbumDetails = '/admin/albums/details';
  static const String adminAlbumEdit = '/admin/albums/edit';
  static const String adminFolderList = '/admin/folders';
  static const String adminFolderCreate = '/admin/folders/create';
  static const String adminFolderDetails = '/admin/folders/details';
  static const String adminFolderRename = '/admin/folders/rename';
  static const String adminFolderMove = '/admin/folders/move';
  static const String adminFolderSettings = '/admin/folders/settings';
  static const String albumShareSettings = '/admin/albums/share-settings';
  static const String sharedGallery = '/shared/gallery';
  static const String adminClientDetails = '/admin/clients/details';
  static const String adminAnalytics = '/admin/analytics';
  static const String adminSettings = '/admin/settings';
  static const String adminTrash = '/admin/trash';



  // Studio management routes
  static const String teamManagement = '/admin/team';
  static const String subscriptionPlans = '/admin/subscription-plans';
  static const String paymentsBilling = '/admin/payments-billing';

  // Client drawer routes
  static const String clientInvitations = '/client/invitations';
  static const String messages = '/messages';
  static const String profile = '/profile';

  static const String chatThread = '/chat/thread';
  static const String discoverStudios = '/discover-studios';
  static const String studioProfile = '/studio-profile';
  static const String favoriteStudios = '/favorite-studios';
  static const String sharedStudios = '/shared-studios';
  static const String studioSharedFolders = '/studio-shared-folders';

  // Legal / support (reachable from Profile menus & drawers on both
  // client and studio sides — see admin_profile_screen.dart,
  // client/profile_screen.dart, about_screen.dart, studio_drawer.dart,
  // and client_drawer.dart, which already reference these route names).
  static const String privacyPolicy = '/legal/privacy-policy';
  static const String termsConditions = '/legal/terms-conditions';
  static const String helpSupport = '/legal/help-support';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final routeName = settings.name ?? '';
    final uri = Uri.tryParse(routeName);
    if (uri != null && uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'shared') {
      final token = uri.pathSegments[1];
      if (token != 'gallery') {
        return _fade(SharedGalleryScreen(token: token));
      }
    }

    switch (settings.name) {
      case splash:
        return _fade(const SplashScreen());
      case pinUnlock:
        final args = settings.arguments as PinUnlockArgs;
        return _fade(PinUnlockScreen(
          correctPin: args.correctPin,
          destinationRoute: args.destinationRoute,
          destinationArguments: args.destinationArguments,
        ));
      case onboarding:
        return _fade(const OnboardingScreen());
      case roleSelection:
        return _fade(const RoleSelectionScreen());
      case login:
        debugPrint('[ROLE_DEBUG] case login, settings.arguments=${settings.arguments}');
        return _fade(LoginScreen(role: settings.arguments as UserRole?));
      case register:
        debugPrint('[ROLE_DEBUG] case register, settings.arguments=${settings.arguments}');
        return _slide(RegisterScreen(role: settings.arguments as UserRole? ?? UserRole.client));
      case forgotPassword:
        return _slide(const ForgotPasswordScreen());
      case checkEmail:
        return _fade(CheckEmailScreen(email: settings.arguments as String? ?? ''));
      case resetPassword:
        final args = settings.arguments;
        if (args is Map) {
          return _fade(ResetPasswordScreen(email: args['email'] as String?, token: args['token'] as String?));
        }
        return _fade(ResetPasswordScreen(token: args as String?));
      case resetSuccess:
        return _fade(const ResetSuccessScreen());
      case emailVerification:
        final args = settings.arguments;
        if (args is Map) {
          return _fade(EmailVerificationScreen(
            email: args['email'] as String? ?? '',
            role: args['role'] as UserRole?,
          ));
        }
        return _fade(EmailVerificationScreen(email: args as String? ?? ''));
      case verificationPending:
        final vpArgs = settings.arguments;
        if (vpArgs is Map) {
          return _fade(VerificationPendingScreen(
            email: vpArgs['email'] as String? ?? '',
            role: vpArgs['role'] as UserRole?,
          ));
        }
        return _fade(VerificationPendingScreen(email: vpArgs as String? ?? ''));
      case otpVerification:
        final args = settings.arguments;
        return _fade(OtpVerificationScreen(contact: args as String? ?? ''));
      case completeProfile:
        return _slide(CompleteProfileScreen(role: settings.arguments as UserRole?));
      case termsPrivacy:
        return _slide(const TermsPrivacyScreen());
      case cameraPermission:
        return _slide(CameraPermissionScreen(role: settings.arguments as UserRole?));
      case photoLibraryPermission:
        return _slide(PhotoLibraryPermissionScreen(role: settings.arguments as UserRole?));
      case pushNotificationPermission:
        return _slide(PushNotificationPermissionScreen(role: settings.arguments as UserRole?));
      case home:
        return _fade(const MainNavScreen());
      case adminHome:
        return _fade(const AdminMainNavScreen());
      case editProfile:
        return _slide(const EditProfileScreen());
      case deleteAccount:
        return _slide(const DeleteAccountScreen());
      case permissions:
        return _slide(const AppPermissionsScreen());

      case collections:
        return _slide(const CollectionsScreen());
      case collectionsDetails:
        return _slide(CollectionDetailsScreen(collectionId: settings.arguments as String));
      case downloadHistory:
        return _slide(const DownloadHistoryScreen());
      case invitations:
        return _slide(const InvitationsScreen());
      case profilePrivacySettings:
        return _slide(const PrivacySettingsScreen());
      case profileAbout:
        return _slide(const AboutScreen());

      case notifications:
        return _slide(const NotificationsScreen());
      case notificationDetail:
        return _slide(NotificationDetailScreen(notification: settings.arguments as NotificationData));
      case search:
        return _slide(const GlobalSearchScreen());
      case searchResults:
        final args = settings.arguments as SearchResultsArgs?;
        return _slide(SearchResultsScreen(initialQuery: args?.query ?? '', initialType: args?.type));
      case storageOverview:
        return _slide(const StorageOverviewScreen());
      case recentActivity:
        return _slide(const RecentActivityScreen());
      case quickActions:
        return _slide(const QuickActionsScreen());

      case faceSearchLanding:
        return _slide(const FaceSearchLandingScreen());
      case faceSearchUpload:
        return _slide(const FaceSearchUploadScreen());
      case faceSearchScanProgressPlaceholder:
        return _slide(FaceSearchScanProgressScreen(file: settings.arguments as File));
      case faceSearchResults:
        return _slide(const FaceSearchResultsScreen());

      case uploadQueue:
        return _fade(const UploadQueueScreen());

      case adminAlbumCreate:
        return _slide(CreateAlbumScreen(folderId: settings.arguments as String?));
      case adminAlbumDetails:
        return _slide(AlbumDetailsScreen(albumId: settings.arguments as String));
      case adminAlbumEdit:
        return _slide(EditAlbumScreen(albumId: settings.arguments as String));
      case adminFolderList:
        return _slide(const FolderListScreen());
      case adminFolderCreate:
        return _slide(CreateFolderScreen(parentId: settings.arguments as String?));
      case adminFolderDetails:
        return _slide(FolderDetailsScreen(folderId: settings.arguments as String));
      case adminFolderRename:
        return _slide(RenameFolderScreen(folderId: settings.arguments as String));
      case adminFolderMove:
        return _slide(MoveFolderScreen(folderId: settings.arguments as String));
      case adminFolderSettings:
        return _slide(FolderSettingsScreen(folderId: settings.arguments as String));

      case media:
        final args = settings.arguments as MediaSearchArgs?;
        return _slide(MediaGridScreen(
          albumId: args?.initialAlbumId,
          folderId: args?.initialFolderId,
          favoritesOnly: args?.favoritesOnly ?? false,
        ));
      case mediaFavorites:
        return _slide(const MediaFavoritesScreen());
      case mediaSearch:
        final mArgs = settings.arguments as MediaSearchArgs?;
        return _slide(MediaSearchScreen(initialArgs: mArgs));
      case mediaFilter:
        return _slide(const MediaFilterScreen());
      case videoGrid:
        final args = settings.arguments as MediaSearchArgs?;
        return _slide(VideoGridScreen(
          albumId: args?.initialAlbumId,
          folderId: args?.initialFolderId,
        ));
      case mediaDetails:
        final args = settings.arguments as MediaDetailsArgs;
        return _slide(MediaDetailsScreen(mediaId: args.mediaId, mediaIds: args.mediaIds));
      case imageViewer:
        final args = settings.arguments as ImageViewerArgs;
        return _fade(ImageViewerScreen(
          mediaIds: args.mediaIds,
          initialIndex: args.initialIndex,
          showWatermark: args.showWatermark,
          allowDownload: args.allowDownload,
          shareLinkId: args.shareLinkId,
          mediaItems: args.mediaItems,
          readOnly: args.readOnly,
        ));
      case videoPlayer:
        final args = settings.arguments as VideoPlayerArgs;
        return _fade(VideoPlayerScreen(
          mediaId: args.mediaId,
          mediaIds: args.mediaIds ?? [args.mediaId],
          initialIndex: args.initialIndex,
          showWatermark: args.showWatermark,
          allowDownload: args.allowDownload,
          shareLinkId: args.shareLinkId,
          mediaItems: args.mediaItems,
          readOnly: args.readOnly,
        ));
      case photoEditor:
        final args = settings.arguments as PhotoEditorArgs;
        return _slide(PhotoEditorScreen(media: args.media));

      case albumShareSettings:
        return _slide(ShareSettingsScreen(albumId: settings.arguments as String));
      case sharedGallery:
        final rawArgs = settings.arguments;
        if (rawArgs is SharedGalleryArgs) {
          return _fade(SharedGalleryScreen(token: rawArgs.token, isPreview: rawArgs.isPreview));
        }
        final token = rawArgs as String? ?? '';
        return _fade(SharedGalleryScreen(token: token));
      case adminClientDetails:
        return _slide(ClientDetailsScreen(clientId: settings.arguments as String? ?? ''));
      case adminAnalytics:
        return _slide(const AnalyticsScreen());
      case adminSettings:
        return _slide(const AdminSettingsScreen());
      case adminTrash:
        return _slide(const TrashScreen());
      case subscriptionPlans:
        return _slide(const SubscriptionPlansScreen());

      case chatThread:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return _slide(ChatThreadScreen(
          threadId: args['threadId'] as String? ?? '',
          connectionId: args['connectionId'] as String? ?? '',
          otherPartyName: args['otherPartyName'] as String? ?? '',
          otherPartyAvatar: args['otherPartyAvatar'] as String?,
        ));
      case discoverStudios:
        return _slide(const DiscoverStudiosScreen());
      case studioProfile:
        return _slide(StudioProfileScreen(studioId: settings.arguments as String));
      case favoriteStudios:
        return _slide(const FavoriteStudiosScreen());
      case sharedStudios:
        return _slide(const SharedStudiosScreen());
      case studioSharedFolders:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return _slide(StudioSharedFoldersScreen(
          studioId: args['studioId'] as String? ?? '',
          folderId: args['folderId'] as String?,
        ));

      case privacyPolicy:
        return _slide(const PrivacyPolicyScreen());
      case termsConditions:
        return _slide(const TermsConditionsScreen());
      case helpSupport:
        return _slide(const HelpSupportScreen());

      default:
        // Unknown routes should never silently redirect to SplashScreen
        // (which auto-navigates to role selection). Instead, pop back to
        // wherever the user came from, or fall back to adminHome.
        return PageRouteBuilder(
          pageBuilder: (context, _, __) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                final nav = Navigator.of(context);
                if (nav.canPop()) {
                  nav.pop();
                } else {
                  nav.pushReplacementNamed(adminHome);
                }
              }
            });
            // Momentary transparent page while the post-frame callback runs.
            return const SizedBox.shrink();
          },
          transitionDuration: Duration.zero,
        );
    }
  }

  static Route<dynamic> _fade(Widget child) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => child,
      transitionsBuilder: (_, animation, __, c) => FadeTransition(opacity: animation, child: c),
      transitionDuration: const Duration(milliseconds: 350),
    );
  }

  static Route<dynamic> _slide(Widget child) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => child,
      transitionsBuilder: (_, animation, __, c) {
        final tween = Tween(begin: const Offset(1, 0), end: Offset.zero).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(position: animation.drive(tween), child: c);
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }
}