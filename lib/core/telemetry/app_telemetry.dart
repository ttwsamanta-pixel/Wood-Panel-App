import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../routing/app_router.dart';
import '../edition/edition.dart';

/// No titles, URLs, search queries, profile data or form contents are logged.
class AppTelemetry {
  static Future<void> start(Ref ref) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    try {
      final analytics = FirebaseAnalytics.instance;
      final crashes = FirebaseCrashlytics.instance;
      await crashes.setCrashlyticsCollectionEnabled(true);
      final previousFlutter = FlutterError.onError;
      final previousPlatform = PlatformDispatcher.instance.onError;
      FlutterError.onError = (details) {
        previousFlutter?.call(details);
        unawaited(crashes.recordFlutterFatalError(details));
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        unawaited(crashes.recordError(error, stack, fatal: true));
        previousPlatform?.call(error, stack);
        return true;
      };
      final router = ref.read(appRouterProvider);
      String? lastScreen;
      Future<void> trackScreen() async {
        try {
          // Keep only the static first path component, excluding IDs and queries.
          final parts = router.routeInformationProvider.value.uri.pathSegments;
          final screen = parts.isEmpty ? 'splash' : parts.first;
          final edition = ref.read(editionProvider).name;
          final key = '$edition/$screen';
          if (key == lastScreen) return;
          lastScreen = key;
          await crashes.setCustomKey('edition', edition);
          await crashes.setCustomKey('screen', screen);
          await analytics.setUserProperty(name: 'edition', value: edition);
          await analytics.logScreenView(screenName: screen);
        } catch (_) {
          // Reporting must never interrupt reading or notification delivery.
        }
      }

      void onRoute() => unawaited(trackScreen());
      router.routeInformationProvider.addListener(onRoute);
      ref.listen(editionProvider, (previous, next) {
        unawaited(trackScreen());
        unawaited(analytics.logEvent(name: 'edition_switch', parameters: {
          'edition': next.name,
        }).catchError((Object _) {}));
      });
      ref.onDispose(() {
        router.routeInformationProvider.removeListener(onRoute);
        FlutterError.onError = previousFlutter;
        PlatformDispatcher.instance.onError = previousPlatform;
      });
      await trackScreen();

      // Explicit debug-only, one-shot diagnostic; never enabled in release.
      const testCrash = bool.fromEnvironment('FIREBASE_TEST_CRASH');
      if (kDebugMode && testCrash) {
        final prefs = await SharedPreferences.getInstance();
        if (!(prefs.getBool('firebase_test_crash_completed_v1') ?? false)) {
          await prefs.setBool('firebase_test_crash_completed_v1', true);
          await analytics.logEvent(name: 'integration_test');
          await crashes.setCustomKey('controlled_test', true);
          Timer(const Duration(seconds: 15), crashes.crash);
        }
      }
    } catch (error) {
      debugPrint('Firebase telemetry setup unavailable: ${error.runtimeType}');
    }
  }
}
