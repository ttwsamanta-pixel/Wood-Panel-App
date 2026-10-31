import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wood_panel_app/core/edition/edition.dart';
import 'package:wood_panel_app/core/edition/edition_navigation.dart';
import 'package:wood_panel_app/core/edition/notification_inbox.dart';
import 'package:wood_panel_app/core/theme/app_theme.dart';
import 'package:wood_panel_app/data/repositories/app_preferences_repository.dart';
import 'package:wood_panel_app/data/repositories/reading_preferences.dart';
import 'package:wood_panel_app/features/profile/preferences_page.dart';
import 'notification_inbox_test.dart' show InboxApi;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'Reading choices and system appearance persist across controller recreation',
      () async {
    SharedPreferences.setMockInitialValues({});
    final controller = ReadingPreferencesController();
    await controller.setSize(ReadingSize.extraLarge);
    await controller.setSpeed(.65);
    await controller.setVoice({'name': 'English', 'locale': 'en-US'});
    controller.dispose();
    final restored = ReadingPreferencesController();
    await restored.ready;
    expect(restored.state.size, ReadingSize.extraLarge);
    expect(restored.state.speed, .65);
    expect(restored.state.voice!['name'], 'English');
    final theme = ThemeModeController(AppPreferencesRepository());
    await theme.setMode(ThemeMode.system);
    expect(await AppPreferencesRepository().themeMode(), ThemeMode.system);
    theme.dispose();
    restored.dispose();
  });
  test('App text scaling preserves phone accessibility scaling', () {
    expect(const ReadingTextScaler(TextScaler.linear(1.5), 1.3).scale(20), 39);
  });
  test('Each edition can opt in independently of browsing', () async {
    for (final selected in Edition.values) {
      final subscribed = <String>[];
      final removed = <String>[];
      await syncEditionPushSubscriptions(
          enabled: true,
          editions: {for (final e in Edition.values) e: e == selected},
          subscribe: (topic) async {
            subscribed.add(topic);
          },
          unsubscribe: (topic) async {
            removed.add(topic);
          });
      expect(subscribed, [selected.topic]);
      expect(removed, [Edition.values.firstWhere((e) => e != selected).topic]);
    }
  });
  test('Legal content supports old plugins and edition-specific replacement',
      () {
    final old = EditionConfig.fromJson(
        Edition.europe, {'schema_version': 1, 'edition': 'europe'});
    expect(old.privacyPolicy, contains('Privacy Policy'));
    expect(old.termsConditions, contains('Terms & Conditions'));
    final updated = EditionConfig.fromJson(Edition.usa, {
      'schema_version': 1,
      'edition': 'usa',
      'privacy_policy': 'USA policy',
      'terms_conditions': 'USA terms'
    });
    expect(updated.privacyPolicy, 'USA policy');
    expect(updated.termsConditions, 'USA terms');
  });
  for (final dark in [false, true]) {
    testWidgets(
        'Preferences fit a narrow phone with extra-large text, dark=$dark',
        (tester) async {
      SharedPreferences.setMockInitialValues({'reading_size': 'extraLarge'});
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('flutter_tts'), (_) async => 1);
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = GoRouter(initialLocation: '/preferences', routes: [
        GoRoute(
            path: '/preferences', builder: (_, __) => const PreferencesPage())
      ]);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            activeConfigProvider
                .overrideWithValue(EditionConfig(edition: Edition.europe)),
            notificationInboxProvider.overrideWith(
                (ref, e) => NotificationInbox(e, clientFactory: InboxApi.new)),
          ],
          child: MaterialApp.router(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: child!))));
      await tester.pumpAndSettle();
      expect(find.text('Follow Phone Settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 10; i++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(find.text('Contact & Support'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    });
  }
}
