// Basic smoke test: the app boots and shows its splash screen without
// throwing. Kept intentionally minimal — most of picgallery's real logic
// (auth flow, API calls, providers) needs a live backend or mocked
// providers to test meaningfully, which belongs in dedicated test files,
// not the default template here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:picgallery/main.dart';
import 'package:picgallery/core/constants/app_constants.dart';
import 'package:picgallery/core/storage/token_storage.dart';
import 'package:picgallery/core/theme/app_theme.dart';
import 'package:picgallery/providers/auth_providers.dart';
import 'package:picgallery/widgets/inputs/custom_text_field.dart';

/// [TokenStorage] is normally backed by flutter_secure_storage, which
/// talks to a platform channel that isn't available in a plain widget
/// test. The splash screen reads it on a real 3-second timer, so we
/// override it here with a no-op version that just says "no saved
/// session" without touching the platform channel.
class _FakeTokenStorage extends TokenStorage {
  @override
  Future<String?> readToken() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    await Hive.initFlutter();
  });

  testWidgets('App boots and shows the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tokenStorageProvider.overrideWithValue(_FakeTokenStorage())],
        child: const PicGallery(),
      ),
    );

    // Splash screen renders the app name as its heading.
    expect(find.text('picgallery'), findsOneWidget);

    // SplashScreen.initState schedules Future.delayed(AppDurations.splash,
    // _bootstrap). Flutter's test binding runs inside a fake-async zone,
    // so we must advance time past that duration (then let the resulting
    // navigation/animation settle) — otherwise the test fails with
    // "Pending timers" when that still-unfired Timer gets torn down.
    await tester.pump(AppDurations.splash);
    await tester.pumpAndSettle();
  });

  testWidgets('Dark mode text fields use dark theme colors', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const Scaffold(
          body: CustomTextField(
            label: 'Email',
            icon: Icons.mail_outline_rounded,
          ),
        ),
      ),
    );

    final text = tester.widget<EditableText>(find.byType(EditableText));
    expect(text.style.color, AppColors.textOnDark);
  });
}