import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wood_panel_app/app/wood_panel_app.dart';
import 'package:wood_panel_app/widgets/wp_logo.dart';

void main() {
  testWidgets('Wood & Panel app boots', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: WoodPanelApp()));

    expect(find.byType(WPLogo), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1400));
  });
}
