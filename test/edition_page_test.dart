import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wood_panel_app/core/edition/edition.dart';
import 'package:wood_panel_app/routing/app_router.dart';

final config =
    StateProvider((ref) => const EditionConfig(edition: Edition.europe));

// Models a screen that captures its data source in initState.
class CapturedSource extends ConsumerStatefulWidget {
  const CapturedSource({super.key});
  @override
  ConsumerState<CapturedSource> createState() => _CapturedSourceState();
}

class _CapturedSourceState extends ConsumerState<CapturedSource> {
  late final String source;
  @override
  void initState() {
    super.initState();
    final selected = ref.read(activeConfigProvider);
    source = '${selected.edition.name}:${selected.managed}';
  }

  @override
  Widget build(BuildContext context) => Text(source);
}

void main() {
  testWidgets('edition pages discard old data on switching and config arrival',
      (tester) async {
    final container = ProviderContainer(overrides: [
      activeConfigProvider.overrideWith((ref) => ref.watch(config)),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EditionPage(child: CapturedSource()))));
    expect(find.text('europe:false'), findsOneWidget);
    container.read(config.notifier).state =
        const EditionConfig(edition: Edition.usa);
    await tester.pump();
    expect(find.text('usa:false'), findsOneWidget);
    expect(find.text('europe:false'), findsNothing);
    container.read(config.notifier).state =
        const EditionConfig(edition: Edition.usa, managed: true);
    await tester.pump();
    expect(find.text('usa:true'), findsOneWidget);
    container.read(config.notifier).state =
        const EditionConfig(edition: Edition.europe, managed: true);
    await tester.pump();
    expect(find.text('europe:true'), findsOneWidget);
  });
}
