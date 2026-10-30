import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wood_panel_app/core/edition/edition.dart';
import 'package:wood_panel_app/data/repositories/app_api_repository.dart';
import 'package:wood_panel_app/features/common/brand_pages.dart';
import 'package:wood_panel_app/features/home/home_screen.dart';

class FakeForms extends AppApiRepository {
  FakeForms() : super(baseUrl: 'https://example.com');
  String? savedSubject;
  @override
  Future<void> subscribeNewsletter(
      {required String email, String? name, String? country}) async {}
  @override
  Future<void> sendContactMessage(
      {required String name,
      required String email,
      required String subject,
      required String message}) async {
    savedSubject = subject;
  }
}

Widget fixture(Widget child, FakeForms api,
    {Edition edition = Edition.europe}) {
  final router = GoRouter(
      initialLocation: '/contact',
      routes: [GoRoute(path: '/contact', builder: (_, __) => child)]);
  return ProviderScope(overrides: [
    editionProvider.overrideWith((ref) => edition),
    editionConfigProvider
        .overrideWith((ref, edition) async => EditionConfig(edition: edition)),
    activeConfigProvider.overrideWithValue(EditionConfig(edition: edition)),
    appApiRepositoryProvider.overrideWithValue(api),
  ], child: MaterialApp.router(routerConfig: router));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final width in [320.0, 390.0]) {
    for (final page in [const PartnerPage(), const ContactPage()]) {
      testWidgets('${page.runtimeType} fits $width', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(fixture(page, FakeForms()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView).first, const Offset(0, -650));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  for (final edition in Edition.values) {
    testWidgets('$edition newsletter success replaces fields', (tester) async {
      await tester.pumpWidget(fixture(
          Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => showNewsletterPopup(context, ''),
                      child: const Text('Open')))),
          FakeForms(),
          edition: edition));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Test Name');
      await tester.enterText(
          find.byType(TextFormField).at(1), 'test@example.com');
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Thank you!'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Contact sends subject and replaces the form on success',
      (tester) async {
    final api = FakeForms();
    await tester.binding.setSurfaceSize(const Size(390, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(fixture(const ContactPage(), api));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Test');
    await tester.enterText(fields.at(1), 'test@example.com');
    await tester.enterText(fields.at(3), 'Partnership enquiry');
    await tester.enterText(fields.at(4), 'Please contact me.');
    await tester.ensureVisible(find.text('Send Message'));
    await tester.tap(find.text('Send Message'));
    await tester.pumpAndSettle();
    expect(api.savedSubject, 'Partnership enquiry');
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Your message has been sent.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
