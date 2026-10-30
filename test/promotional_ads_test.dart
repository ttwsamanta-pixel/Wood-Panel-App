import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wood_panel_app/data/repositories/content_providers.dart';
import 'package:wood_panel_app/data/repositories/mock_content_repository.dart';
import 'package:wood_panel_app/features/common/simple_screens.dart';
import 'package:wood_panel_app/core/edition/edition.dart';
import 'package:wood_panel_app/widgets/promotional_ads.dart';

const banner = {
  'image_url': 'https://example.com/ad.png',
  'link_url': '',
  'label': 'Test ad'
};
Widget fixture(Widget child, {bool enabled = true}) => ProviderScope(
      overrides: [
        activeConfigProvider.overrideWithValue(EditionConfig(
            edition: Edition.usa,
            inlineAds: enabled ? [banner] : [],
            footerAds: enabled ? [banner] : []))
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  test('footer rotation is ordered across routes, tabs and refreshes', () {
    final rotation = FooterRotation();
    rotation.visit('/feed');
    expect(rotation.index % 2, 0);
    rotation.visit('/home');
    expect(rotation.index % 2, 1);
    rotation.visit('/home'); // Multiple mounted scaffolds see the same route.
    expect(rotation.index % 2, 1);
    rotation.refresh();
    expect(rotation.index % 2, 0);
    rotation.nextTab();
    expect(rotation.index % 2, 1);
    rotation.dispose();
  });
  for (final size in ['350x50', '350x100']) {
    testWidgets('footer renders selected $size ratio', (tester) async {
      await tester.pumpWidget(ProviderScope(
          overrides: [
            activeConfigProvider.overrideWithValue(
                EditionConfig(edition: Edition.europe, footerAds: [
              {...banner, 'size': size}
            ])),
          ],
          child: const MaterialApp(
              home: Scaffold(bottomNavigationBar: FooterAdvertisement()))));
      final actual = tester.getSize(find.byType(PromoImage));
      expect(actual.width, 350);
      expect(actual.height, size == '350x100' ? 100 : 50);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('feed fits a small screen with footer and square ad pages',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const config = EditionConfig(edition: Edition.europe, inlineAds: [
      banner
    ], footerAds: [
      {...banner, 'size': '350x100'}
    ]);
    final router = GoRouter(initialLocation: '/feed', routes: [
      GoRoute(path: '/feed', builder: (_, __) => const FeedScreen())
    ]);
    await tester.pumpWidget(ProviderScope(overrides: [
      activeConfigProvider.overrideWithValue(config),
      editionConfigProvider(Edition.europe).overrideWith((ref) async => config),
      contentRepositoryProvider.overrideWithValue(MockContentRepository()),
    ], child: MaterialApp.router(routerConfig: router)));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    final button = find.text('Read Full Article').first;
    expect(button.hitTestable(), findsOneWidget);
    expect(tester.getBottomRight(button).dy,
        lessThan(tester.getTopLeft(find.byType(FooterAdvertisement)).dy));
    final pager = tester.widget<PageView>(find.byType(PageView));
    pager.controller!.jumpToPage(3);
    await tester.pump();
    expect(find.byType(InlineAdAfter), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });
  test('square ads repeat in order after every three content items', () {
    expect([
      for (var count = 3; count <= 24; count += 3) rotatingAdIndex(count, 4)
    ], [
      0,
      1,
      2,
      3,
      0,
      1,
      2,
      3
    ]);
    for (var count = 0; count <= 50; count++) {
      final slots = count + adCountForItems(count);
      final content = [
        for (var index = 0; index < slots; index++)
          if (!isAdSlot(index)) contentIndexForSlot(index)
      ];
      expect(content, List.generate(count, (i) => i));
    }
  });
  test('ad config is optional and rejects non-HTTPS images', () {
    final config = EditionConfig.fromJson(Edition.usa, {
      'schema_version': 1,
      'edition': 'usa',
      'inline_ads': [
        banner,
        {'image_url': 'javascript:bad'}
      ],
      'footer_ads': [{...banner, 'size': '350x100'}, banner]
    });
    expect(config.inlineAds.length, 1);
    expect(config.footerAds.map((ad) => ad['size']), ['350x100', '350x50']);
  });
  testWidgets('no ads leave no visible placeholders', (tester) async {
    await tester.pumpWidget(fixture(
        const Column(children: [
          InlineAdAfter(completedItems: 3),
          FooterAdvertisement()
        ]),
        enabled: false));
    expect(find.byType(PromoImage), findsNothing);
    expect(find.text('Advertisement'), findsNothing);
  });
  testWidgets('inline image appears only at the third content boundary',
      (tester) async {
    await tester.pumpWidget(fixture(const SingleChildScrollView(
        child: Column(children: [
      InlineAdAfter(completedItems: 2),
      InlineAdAfter(completedItems: 3)
    ]))));
    expect(find.byType(PromoImage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('footer minimizes, expands, closes and resets on tab navigation',
      (tester) async {
    final page = ValueNotifier('news');
    await tester.pumpWidget(fixture(ValueListenableBuilder<String>(
        valueListenable: page,
        builder: (_, key, __) => FooterAdvertisement(pageKey: key))));
    expect(find.byType(PromoImage), findsOneWidget);
    await tester.tap(find.byTooltip('Minimize advertisement'));
    await tester.pump();
    expect(find.byType(PromoImage), findsNothing);
    await tester.tap(find.byTooltip('Expand advertisement'));
    await tester.pump();
    expect(find.byType(PromoImage), findsOneWidget);
    await tester.tap(find.byTooltip('Close advertisement'));
    await tester.pump();
    expect(find.text('Advertisement'), findsNothing);
    page.value = 'videos';
    await tester.pump();
    expect(find.byType(PromoImage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    page.dispose();
  });
}
