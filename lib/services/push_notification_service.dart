import 'dart:convert';
import 'dart:developer' as developer;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/routes/app_routes.dart';
import '../models/user.dart';
import '../providers/auth_providers.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  developer.log('Handling a background message: ${message.messageId}');
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  /// Same key passed to [MaterialApp] in main.dart — lets a tapped
  /// notification navigate without needing a BuildContext from inside a
  /// widget, mirroring [DeepLinkService]'s approach for
  /// picgallery://-scheme links.
  GlobalKey<NavigatorState>? _navigatorKey;

  Future<void> init(ApiClient apiClient, GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;

    // Request permission (especially required for iOS)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      developer.log('User granted permission for push notifications');
    } else {
      developer.log('User declined or has not accepted permission');
    }

    // Set up background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize local notifications for foreground display. Wiring
    // onDidReceiveNotificationResponse here is what lets a tap on the
    // foreground banner (shown by _showForegroundNotification below)
    // deep-link the same way a background/terminated-state tap does —
    // previously nothing was registered, so foreground taps went nowhere.
    const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = Map<String, dynamic>.from(jsonDecode(payload) as Map);
          _handleNotificationTap(data);
        } catch (e) {
          developer.log('Failed to decode notification payload: $e');
        }
      },
    );

    // Create high importance channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // name
      description: 'This channel is used for important notifications.', // description
      importance: Importance.max,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Listen to token updates and sync with backend
    _firebaseMessaging.getToken().then((token) {
      if (token != null) {
        syncFcmToken(apiClient, token: token);
      }
    });

    _firebaseMessaging.onTokenRefresh.listen((token) {
      syncFcmToken(apiClient, token: token);
    });

    // Handle incoming messages in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      developer.log('Got a message whilst in the foreground!');
      developer.log('Message data: ${message.data}');

      if (message.notification != null) {
        developer.log('Message also contained a notification: ${message.notification}');
        _showForegroundNotification(message, channel);
      }
    });

    // App was backgrounded (not terminated) when the notification was
    // tapped — this previously had no listener at all, so the app would
    // simply come to the foreground with no navigation.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      developer.log('Notification tapped while backgrounded: ${message.data}');
      _handleNotificationTap(message.data);
    });

    // App was fully terminated and launched by tapping the notification.
    // Same cold-start gap as above; the navigator may not exist yet on
    // the very first frame, so poll briefly for it (same pattern
    // DeepLinkService.init uses for a cold-start deep link).
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      for (var i = 0; i < 25 && navigatorKey.currentContext == null; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      _handleNotificationTap(initialMessage.data);
    }
  }

  void _showForegroundNotification(RemoteMessage message, AndroidNotificationChannel channel) {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null) {
      _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        // Carries the FCM data payload through to
        // onDidReceiveNotificationResponse so a tap on this foreground
        // banner deep-links exactly like a background/terminated tap.
        payload: jsonEncode(message.data),
      );
    }
  }

  /// Routes a tapped notification based on its `data` payload — the
  /// same `{"type": ..., "connection_id"/"album_id"/"folder_id": ...}`
  /// shape every backend call site (`connections.py`, `studios.py`,
  /// `studio_shares.py`, `send_plan_reminders.py`) already sends.
  ///
  /// The Studio's `notificationDetail` route needs a full
  /// [NotificationData] object (not just an id), which isn't available
  /// from a raw push payload, so this opens the Notifications *list*
  /// screen instead — the same "open the list, don't guess the detail"
  /// choice `NotificationTile`/`NotificationsScreen` already make for
  /// every other entry point.
  ///
  /// Role-gated the same way `RecentActivitySection`/`HomeScreen` guard
  /// `AppRoutes.notifications`: that route is the Studio's
  /// `NotificationsScreen` (backed by `adminDashboardProvider`) and
  /// shows the wrong data — or fails to load — for a client. Clients'
  /// notifications live on the Alerts bottom-nav tab instead, so a
  /// client tap lands on `AppRoutes.home` (MainNavScreen) rather than
  /// guessing at a tab index from here.
  void _handleNotificationTap(Map<String, dynamic> data) {
    final navigatorKey = _navigatorKey;
    final navigator = navigatorKey?.currentState;
    final context = navigatorKey?.currentContext;
    if (navigator == null || context == null || !context.mounted) return;

    AppUser? user;
    try {
      user = ProviderScope.containerOf(context, listen: false).read(authProvider).valueOrNull;
    } catch (e) {
      developer.log('Could not read auth state for notification tap: $e');
    }
    if (user == null) return;

    if (user.role == AppUserRole.photographer) {
      navigator.pushNamed(AppRoutes.notifications);
    } else {
      navigator.pushNamed(AppRoutes.home);
    }
  }

  /// Syncs the device FCM token to the backend. Pass [token] if you
  /// already have it; otherwise it fetches from Firebase automatically.
  /// Safe to call any time after login — silently no-ops if no token.
  Future<void> syncFcmToken(ApiClient apiClient, {String? token}) async {
    try {
      final t = token ?? await _firebaseMessaging.getToken();
      if (t == null) return;
      developer.log('Syncing FCM token: $t');
      await apiClient.put('/auth/fcm-token', body: {'fcm_token': t});
    } catch (e) {
      developer.log('Failed to sync FCM token: $e');
    }
  }
}