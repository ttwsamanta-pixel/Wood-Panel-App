import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wood_panel_app/core/edition/edition.dart';
import 'package:wood_panel_app/core/edition/notification_inbox.dart';
import 'package:wood_panel_app/features/profile/notification_screen.dart';
import 'notification_inbox_test.dart' show InboxApi;

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('Inbox tabs and reading a notification at width $width',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = GoRouter(initialLocation: '/notifications', routes: [
        GoRoute(
            path: '/notifications',
            builder: (_, __) => const NotificationScreen()),
        GoRoute(
            path: '/article/:id',
            builder: (_, __) => const Scaffold(body: Text('Article opened'))),
      ]);
      await tester.pumpWidget(ProviderScope(overrides: [
        activeConfigProvider
            .overrideWithValue(EditionConfig(edition: Edition.europe)),
        notificationInboxProvider.overrideWith((ref, edition) =>
            NotificationInbox(edition, clientFactory: InboxApi.new)),
      ], child: MaterialApp.router(routerConfig: router)));
      await tester.pumpAndSettle();
      expect(find.text('All (2)'), findsOneWidget);
      expect(find.text('Unread (2)'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('News 1'));
      await tester.pumpAndSettle();
      expect(find.text('Article opened'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unread (1)'));
      await tester.pumpAndSettle();
      expect(find.text('News 1'), findsNothing);
      expect(find.text('News 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    });
  }
}
