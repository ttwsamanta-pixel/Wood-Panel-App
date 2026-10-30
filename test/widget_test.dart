import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wood_panel_app/core/edition/edition.dart';
import 'package:wood_panel_app/core/edition/edition_navigation.dart';

import 'package:wood_panel_app/app/wood_panel_app.dart';
import 'package:wood_panel_app/widgets/wp_components.dart';

void main() {
  testWidgets('Wood & Panel app boots', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(overrides: [
      editionConfigProvider.overrideWith(
          (ref, edition) async => EditionConfig(edition: edition)),
      editionNavigationProvider.overrideWith((ref) => EditionNavigation(ref)),
    ], child: const WoodPanelApp()));

    expect(find.byType(WPPageLoader), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1400));
  });
}
