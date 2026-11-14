import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wood_panel_app/core/edition/edition.dart';
import 'package:wood_panel_app/core/edition/edition_navigation.dart';
import 'package:wood_panel_app/features/onboarding/notification_permission_screen.dart';

class PermissionService extends EditionNavigation {
  PermissionService(super.ref, this.allowed) {
    ready = Future.value();
  }
  final bool allowed;
  int requests = 0;
  @override
  Future<void> setEnabled(bool enabled) async {
    requests++;
    if (allowed) {
      ref.read(editionPushProvider.notifier).state = {
        for (final edition in Edition.values) edition: enabled,
      };
    } else {
      ref.read(notificationStatusProvider.notifier).state = 'Permission denied';
    }
  }
}

void main() {
  for (final action in ['skip', 'allow', 'deny']) {
    testWidgets('Notification onboarding: $action', (tester) async {
      SharedPreferences.setMockInitialValues({});
      late PermissionService service;
      final router =
          GoRouter(initialLocation: '/enable-notifications', routes: [
        GoRoute(
            path: '/enable-notifications',
            builder: (_, __) => const NotificationPermissionScreen()),
        GoRoute(
            path: '/feed',
            builder: (_, __) => const Scaffold(body: Text('Feed destination'))),
      ]);
      await tester.pumpWidget(ProviderScope(overrides: [
        editionConfigProvider
            .overrideWith((ref, e) async => EditionConfig(edition: e)),
        editionNavigationProvider.overrideWith(
            (ref) => service = PermissionService(ref, action == 'allow')),
      ], child: MaterialApp.router(routerConfig: router)));
      await tester.pumpAndSettle();
      await tester
          .tap(find.text(action == 'skip' ? 'Not Now' : 'Allow Notifications'));
      await tester.pumpAndSettle();
      if (action == 'deny') {
        expect(find.text('Permission denied'), findsOneWidget);
        expect(
            (await SharedPreferences.getInstance())
                .getBool('notification_prompt_seen_v1'),
            isNull);
        await tester.tap(find.text('Not Now'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Feed destination'), findsOneWidget);
      expect(
          (await SharedPreferences.getInstance())
              .getBool('notification_prompt_seen_v1'),
          isTrue);
      if (action != 'skip') expect(service.requests, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    });
  }
}
