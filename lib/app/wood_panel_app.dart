import '../data/repositories/reading_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../routing/app_router.dart';
import '../core/theme/app_theme.dart';
import '../data/repositories/app_preferences_repository.dart';
import '../core/edition/edition.dart';
import '../core/edition/edition_navigation.dart';
import '../widgets/wp_components.dart';
import '../widgets/promotional_ads.dart';

class WoodPanelApp extends ConsumerWidget {
  const WoodPanelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    ref.watch(editionNavigationProvider);
    final reading = ref.watch(readingPreferencesProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    final config = ref.watch(activeConfigProvider);
    final ready = ref.watch(editionConfigProvider(config.edition));

    return MaterialApp.router(
      key: ValueKey(config.edition.name),
      title: 'Wood And Panel',
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: ReadingTextScaler(
                  MediaQuery.textScalerOf(context), reading.size.scale)),
          child: ready.hasValue
              ? KeyedSubtree(
                  // Recreate stateful screens when the selected site's fresh
                  // configuration arrives, not just when its logo changes.
                  key: ObjectKey(config),
                  child: PromoImageWarmup(child: child!))
              : const Scaffold(body: WPPageLoader())),
      theme: AppTheme.light().copyWith(
          colorScheme: AppTheme.light()
              .colorScheme
              .copyWith(primary: config.primary, secondary: config.secondary)),
      darkTheme: AppTheme.dark().copyWith(
          colorScheme: AppTheme.dark()
              .colorScheme
              .copyWith(primary: config.primary, secondary: config.secondary)),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
