import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/network/api_client.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'providers/auth_providers.dart';
import 'providers/settings_provider.dart';
import 'services/deep_link_service.dart';

/// Lets DeepLinkService navigate / show SnackBars after a
/// picgallery://payment-success|payment-failed link arrives, without
/// needing a BuildContext from inside a widget.
final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Opens the on-device Hive boxes the Admin Dashboard and the local-only
  // media/albums/folders/onboarding/settings/upload-queue features persist
  // to, so the very first frame can already read saved state.
  await Hive.initFlutter();

  // The backend now has a permanent public URL baked into ApiClient's
  // default (https://api.picgallery.in), so no saved/manual host is
  // needed anymore.
  final apiClient = ApiClient();

  runApp(
    ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(apiClient)],
      child: const PicGallery(),
    ),
  );

  // Start listening for picgallery://payment-success|payment-failed links
  // from the subscription checkout website (see SubscriptionPlansScreen).
  await DeepLinkService.instance.init(navigatorKey);
}

class PicGallery extends ConsumerWidget {
  const PicGallery({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    final themeMode = switch (settings.themeMode) {
      'Light' => ThemeMode.light,
      'Dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'picgallery',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: themeMode,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      navigatorObservers: [routeObserver],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}