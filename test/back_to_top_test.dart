import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wood_panel_app/widgets/back_to_top.dart';

void main() {
  testWidgets('Back to top returns the article scroll position to zero',
      (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: BackToTop(
                child: ListView(
                    controller: controller,
                    children: const [SizedBox(height: 3000)])))));
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(240));
    await tester.tap(find.byTooltip('Back to top'));
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
