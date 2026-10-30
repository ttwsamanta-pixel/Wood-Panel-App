import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wood_panel_app/core/edition/edition.dart';
import 'package:wood_panel_app/data/repositories/app_api_repository.dart';
import 'package:wood_panel_app/data/repositories/user_profile_repository.dart';
import 'package:wood_panel_app/features/profile/profile_page.dart';
import 'package:wood_panel_app/features/profile/profile_editor.dart';
import 'package:wood_panel_app/widgets/app_drawer.dart';

class ProfileApi extends AppApiRepository {
  ProfileApi() : super(baseUrl: 'https://example.com');
  bool fail = false;
  String? savedToken;
  @override
  Future<void> saveProfile(
      {required String name,
      required String email,
      required String photo,
      required String token}) async {
    if (fail) throw Exception('offline');
    savedToken = token;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Social defaults, edition overrides and hidden links stay independent',
      () {
    final europe = EditionConfig.fromJson(
        Edition.europe, {'schema_version': 1, 'edition': 'europe'});
    final usa = EditionConfig.fromJson(Edition.usa, {
      'schema_version': 1,
      'edition': 'usa',
      'social_links': {
        'facebook': 'https://example.com/usa',
        'x': '',
        'youtube': 'javascript:bad'
      }
    });
    expect(
        europe.socialLinks['facebook'], 'https://www.facebook.com/woodpanel');
    expect(usa.socialLinks['facebook'], 'https://example.com/usa');
    expect(usa.socialLinks['x'], '');
    expect(usa.socialLinks['youtube'], '');
    expect(usa.socialLinks['whatsapp'], 'https://wa.me/4915222067848');
  });
  test('Skip is remembered without inventing user details', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
        (await container.read(userProfileProvider.future)).displayName, 'User');
    await container.read(userProfileProvider.notifier).skip();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('profile_prompt_seen_v1'), true);
    expect(prefs.getString('user_profile_v1'), isNull);
  });
  test(
      'Profile persists only after server success and reuses its private token',
      () async {
    final api = ProfileApi();
    final container = ProviderContainer(
        overrides: [appApiRepositoryProvider.overrideWithValue(api)]);
    addTearDown(container.dispose);
    await container.read(userProfileProvider.future);
    final controller = container.read(userProfileProvider.notifier);
    await controller
        .save(const UserProfile(name: 'Reader', email: 'reader@example.com'));
    final token = api.savedToken;
    expect(token, matches(RegExp(r'^[a-f0-9]{64}$')));
    await controller
        .save(const UserProfile(name: 'Updated', email: 'reader@example.com'));
    expect(api.savedToken, token);
    api.fail = true;
    await expectLater(
        controller.save(
            const UserProfile(name: 'Not saved', email: 'reader@example.com')),
        throwsException);
    expect(container.read(userProfileProvider).requireValue.name, 'Updated');
    final restored = ProviderContainer();
    addTearDown(restored.dispose);
    expect((await restored.read(userProfileProvider.future)).name, 'Updated');
  });
  for (final width in [320.0, 390.0]) {
    for (final edition in Edition.values) {
      testWidgets('$edition Profile and menu fit $width', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final router = GoRouter(routes: [
          GoRoute(path: '/', builder: (_, __) => const ProfilePage())
        ]);
        addTearDown(router.dispose);
        await tester.pumpWidget(ProviderScope(overrides: [
          editionProvider.overrideWith((ref) => edition),
          editionConfigProvider
              .overrideWith((ref, e) async => EditionConfig(edition: e)),
          activeConfigProvider
              .overrideWithValue(EditionConfig(edition: edition)),
          profileStatsProvider.overrideWith((ref) async => [2, 1, 1, 3]),
        ], child: MaterialApp.router(routerConfig: router)));
        await tester.pumpAndSettle();
        expect(find.text('User'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView).first, const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
        await tester.pumpAndSettle();
        expect(find.byType(AppDrawer), findsOneWidget);
        expect(find.descendant(of:find.byType(AppDrawer),matching:find.text('Subscribe')),findsNothing);
        expect(find.descendant(of:find.byType(AppDrawer),matching:find.text('Newsletter')),findsOneWidget);
        final menuScroll = tester.state<ScrollableState>(find
            .descendant(
                of: find.byType(AppDrawer), matching: find.byType(Scrollable))
            .first);
        expect(menuScroll.position.maxScrollExtent, lessThanOrEqualTo(1));
        expect(find.text('App Version 0.1.0').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets('Welcome form has name, email, profile icon and Skip without photo upload', (tester) async {
    await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: ProfileEditor(firstLaunch: true))));
    await tester.pumpAndSettle();
    expect(find.text('Skip'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byIcon(Icons.add_a_photo_outlined), findsNothing);
    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
