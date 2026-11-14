import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wood_panel_app/core/edition/availability.dart';
import 'package:wood_panel_app/core/edition/availability_gate.dart';
import 'package:wood_panel_app/core/edition/edition.dart';
import 'package:wood_panel_app/features/profile/preferences_page.dart';

void main() {
  test('Old config and malformed thresholds cannot lock readers out', () {
    for (final json in [
      null,
      [],
      {'android_minimum': -1},
      {'android_minimum': 'bad'}
    ]) {
      expect(
          Availability.fromJson(json)
              .evaluate(build: 1, ios: false, hasStore: true),
          AccessState.available);
    }
  });
  test('Minimum is strict and thresholds are platform-specific', () {
    const policy = Availability(
        androidMinimum: 10, androidLatest: 12, iosMinimum: 3, iosLatest: 4);
    expect(policy.evaluate(build: 9, ios: false, hasStore: true),
        AccessState.requiredUpdate);
    expect(policy.evaluate(build: 10, ios: false, hasStore: true),
        AccessState.optionalUpdate);
    expect(policy.evaluate(build: 12, ios: false, hasStore: true),
        AccessState.available);
    expect(policy.evaluate(build: 4, ios: true, hasStore: true),
        AccessState.available);
    expect(policy.evaluate(build: null, ios: false, hasStore: true),
        AccessState.available);
    expect(policy.evaluate(build: 1, ios: false, hasStore: false),
        AccessState.available);
  });
  test('Maintenance takes precedence over update policy', () {
    expect(
        const Availability(maintenance: true, androidMinimum: 10)
            .evaluate(build: 1, ios: false, hasStore: true),
        AccessState.maintenance);
  });

  Future<void> pumpGate(WidgetTester tester, Availability policy) async {
    final config = EditionConfig(
        edition: Edition.europe,
        availability: policy,
        appStoreUrl:
            'https://play.google.com/store/apps/details?id=com.woodandpanel.mobile');
    await tester.pumpWidget(ProviderScope(
        overrides: [
          activeConfigProvider.overrideWithValue(config),
          editionConfigProvider(Edition.europe)
              .overrideWith((ref) async => config),
          appVersionProvider.overrideWith((ref) async => PackageInfo(
              appName: 'Test',
              packageName: 'test',
              version: '1.0.0',
              buildNumber: '1')),
        ],
        child:
            const MaterialApp(home: AvailabilityGate(child: Text('Reader')))));
    await tester.pumpAndSettle();
  }

  testWidgets('Optional update offers Later and restores the reader',
      (tester) async {
    await pumpGate(tester, const Availability(androidLatest: 2));
    expect(find.text('Update available'), findsOneWidget);
    await tester.ensureVisible(find.text('Later'));
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('Reader'), findsOneWidget);
  });
  testWidgets('Required update hides reader and does not offer Later',
      (tester) async {
    await pumpGate(tester, const Availability(androidMinimum: 2));
    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Later'), findsNothing);
    expect(find.text('Reader'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });
  testWidgets('Maintenance provides an alternate edition', (tester) async {
    await pumpGate(tester, const Availability(maintenance: true));
    expect(find.text('Open USA edition'), findsOneWidget);
    expect(find.text('Reader'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Small phone keeps controls reachable for every blocked state',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final policy in [
      const Availability(maintenance: true),
      const Availability(androidLatest: 2),
      const Availability(androidMinimum: 2),
    ]) {
      await tester.pumpWidget(const SizedBox());
      await pumpGate(tester, policy);
      await tester.ensureVisible(find.text('Retry'));
      expect(tester.takeException(), isNull);
      expect(find.text('Reader'), findsNothing);
    }
  });
}
