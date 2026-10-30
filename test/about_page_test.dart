import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wood_panel_app/core/edition/edition.dart';
import 'package:wood_panel_app/features/common/about_page.dart';
import 'package:wood_panel_app/widgets/regional_page_content.dart';

const content =
    '<div><h1>About Us</h1><p>Edition introduction.</p><h2>Features of the Woodworking Magazine</h2><ul><li>News and insights</li><li><a href="https://example.com">More information</a></li></ul><p><strong>Get More Online</strong></p><p>Online benefits.</p></div>';
void main() {
  test('Website headings become cards without losing linked content', () {
    final sections = aboutSections(content, 'Wood & Panel USA');
    expect(sections.length, 3);
    expect(sections.first.title, 'Wood & Panel USA');
    expect(sections[1].html, contains('https://example.com'));
    expect(sections.last.title, 'Get More Online');
    expect(aboutSections('', 'About'), isEmpty);
    expect(
        aboutSections('<script>bad()</script>plain text', 'About').single.html,
        '<p>plain text</p>');
  });
  for (final edition in Edition.values) {
    for (final width in [320.0, 390.0]) {
      testWidgets('$edition About cards and social banner fit $width',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        await tester.binding.setSurfaceSize(Size(width, 850));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final config =
            EditionConfig(edition: edition, managed: true, aboutPageId: 42);
        final router = GoRouter(initialLocation: '/about', routes: [
          GoRoute(path: '/about', builder: (_, __) => const AboutPage())
        ]);
        await tester.pumpWidget(ProviderScope(overrides: [
          editionProvider.overrideWith((ref) => edition),
          editionConfigProvider.overrideWith((ref, edition) async => config),
          activeConfigProvider.overrideWithValue(config),
          regionalPageProvider(42).overrideWith((ref) async => content),
        ], child: MaterialApp.router(routerConfig: router)));
        await tester.pumpAndSettle();
        expect(find.text('Wood & Panel ${edition.label}'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView).first, const Offset(0, -900));
        await tester.pumpAndSettle();
        expect(find.text('Stay Connected').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        router.dispose();
      });
    }
  }
}
