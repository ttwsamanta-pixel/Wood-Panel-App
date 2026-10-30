import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wood_panel_app/core/edition/edition.dart';
import 'package:wood_panel_app/core/edition/notification_inbox.dart';
import 'package:wood_panel_app/features/profile/notification_screen.dart';
import 'notification_inbox_test.dart' show InboxApi;

class LayoutInboxApi extends InboxApi {
  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? queryParameters}) async {
    final result = await super
        .get<Map<String, dynamic>>(path, queryParameters: queryParameters);
    for (final item in result['items']) {
      item['category'] = 'Industry news';
      item['body'] =
          'A long article preview describing the latest news from the woodworking industry and its manufacturers.';
      item['sent_at'] =
          DateTime.now().subtract(const Duration(hours: 2)).toIso8601String();
    }
    return result as T;
  }
}

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
            NotificationInbox(edition, clientFactory: LayoutInboxApi.new)),
      ], child: MaterialApp.router(routerConfig: router)));
      await tester.pumpAndSettle();
      expect(find.text('All (2)'), findsOneWidget);
      expect(find.text('Unread (2)'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final category = tester.getTopLeft(find.text('INDUSTRY NEWS').first);
      final time = tester.getTopLeft(find.text('2h ago').first);
      expect((category.dy - time.dy).abs(), lessThan(5));
      expect(time.dx, greaterThan(category.dx));
      expect(
          tester.getTopLeft(find.text('News 2')).dy -
              tester.getTopLeft(find.text('News 1')).dy,
          lessThan(125));
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
