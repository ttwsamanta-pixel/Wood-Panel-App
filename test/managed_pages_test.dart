import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wood_panel_app/core/edition/edition.dart';
import 'package:wood_panel_app/features/profile/managed_pages.dart';
import 'package:wood_panel_app/features/profile/profile_page.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Visibility requires activation and named entries, isolated by edition',
      () {
    final europe = EditionConfig.fromJson(Edition.europe, {
      'schema_version': 1,
      'edition': 'europe',
      'group_media_enabled': true,
      'clients_enabled': true,
      'group_media': [
        {'name': 'Brand', 'link_url': 'javascript:bad'},
        {'name': ''}
      ],
    });
    final usa = EditionConfig.fromJson(
        Edition.usa, {'schema_version': 1, 'edition': 'usa'});
    expect(europe.showGroupMedia, true);
    expect(europe.showClients, false);
    expect(europe.groupMedia.single['link_url'], '');
    expect(usa.showGroupMedia, false);
    expect(usa.premiumEnabled, false);
  });
  for (final edition in Edition.values) {
    for (final width in [320.0, 390.0]) {
      testWidgets('Managed pages and profile: $edition at $width',
          (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final config = EditionConfig(
            edition: edition,
            groupMediaEnabled: true,
            clientsEnabled: true,
            premiumEnabled: true,
            groupMedia: const [
              {
                'name': 'Wood & Panel',
                'description': 'Wood, Panels & Surface Industry',
                'link_url': 'https://example.com'
              },
              {
                'name': 'Ply Reporter',
                'description': 'Plywood & Wood Panel News'
              },
            ],
            clients: const [
              {'name': 'Greenpanel'},
              {'name': 'CenturyPly'}
            ]);
        final router = GoRouter(initialLocation: '/group-media', routes: [
          GoRoute(
              path: '/group-media',
              builder: (_, __) => const BrandDirectoryPage()),
          GoRoute(
              path: '/clients',
              builder: (_, __) => const BrandDirectoryPage(clients: true)),
          GoRoute(path: '/subscribe', builder: (_, __) => const PremiumPage()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
          GoRoute(
              path: '/contact',
              builder: (_, __) => const Scaffold(body: Text('Enquiry form'))),
        ]);
        addTearDown(router.dispose);
        final container = ProviderContainer(overrides: [
          editionProvider.overrideWith((ref) => edition),
          activeConfigProvider.overrideWithValue(config),
          editionConfigProvider.overrideWith((ref, e) async => config),
          premiumCoversProvider.overrideWith((ref) async => []),
          profileStatsProvider.overrideWith((ref) async => [0, 0, 0, 0]),
        ]);
        addTearDown(container.dispose);
        await tester.pumpWidget(UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
                theme: ThemeData(
                    colorScheme:
                        ColorScheme.fromSeed(seedColor: config.primary)),
                routerConfig: router)));
        await tester.pumpAndSettle();
        expect(find.text('Ply Reporter'), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
        expect(tester.takeException(), isNull);
        router.go('/clients');
        await tester.pumpAndSettle();
        expect(find.text('Greenpanel'), findsOneWidget);
        expect(tester.takeException(), isNull);
        router.go('/subscribe');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Subscribe Now'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Subscribe Now'));
        await tester.pumpAndSettle();
        expect(find.text('Enquiry form'), findsOneWidget);
        router.go('/profile');
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView).first, const Offset(0, -1500));
        await tester.pumpAndSettle();
        expect(find.text('Group Media'), findsOneWidget);
        expect(find.text('Our Clients'), findsOneWidget);
        expect(find.text('Premium Subscribe'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
