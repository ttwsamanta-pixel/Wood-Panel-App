import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wood_panel_app/core/edition/edition.dart';
import 'package:wood_panel_app/data/models/content_models.dart';
import 'package:wood_panel_app/data/repositories/wallpaper_repository.dart';
import 'package:wood_panel_app/widgets/issue_highlights.dart';

void main() {
  test('six bimonthly issues and annual volume, including cached older values',
      () {
    for (var month = 1; month <= 12; month++) {
      final issue = MagazineIssue.fromJson({
        'date': DateTime(2026, month).toIso8601String(),
        'issueNumber': '10'
      });
      expect(issue.volume, '18');
      expect(issue.issueNumber, '${(month + 1) ~/ 2}');
    }
    expect(MagazineIssue.fromJson({'date': '2022-02-01'}).volume, '14');
  });
  test('disabling defaults preserves custom wallpapers in both editions', () {
    for (final edition in Edition.values) {
      for (final enabled in [true, false]) {
        final container = ProviderContainer(overrides: [
          activeConfigProvider.overrideWithValue(EditionConfig(
              edition: edition,
              managed: true,
              defaultWallpapers: enabled,
              wallpapers: const [
                {
                  'id': 'custom',
                  'title': 'Custom',
                  'category': 'Wood',
                  'image_url': 'https://example.com/wood.jpg'
                }
              ]))
        ]);
        expect(
            container.read(wallpaperCatalogProvider).length, enabled ? 4 : 1);
        expect(container.read(wallpaperCatalogProvider).last.title, 'Custom');
        container.dispose();
      }
    }
  });
  testWidgets('highlights hide when empty and support swiping populated points',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: IssueHighlights(points: []))));
    expect(find.text('In This Issue'), findsNothing);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: IssueHighlights(points: ['Cover story', 'Materials']))));
    expect(find.text('In This Issue'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
