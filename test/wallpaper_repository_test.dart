import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wood_panel_app/data/repositories/wallpaper_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saved wallpapers persist across provider recreation and can be removed',
      () async {
    final first = ProviderContainer();
    await first.read(savedWallpapersProvider.future);
    await first.read(savedWallpapersProvider.notifier).toggle('nature-1');
    first.dispose();

    final reopened = ProviderContainer();
    addTearDown(reopened.dispose);
    expect(await reopened.read(savedWallpapersProvider.future), {'nature-1'});
    await reopened.read(savedWallpapersProvider.notifier).toggle('nature-1');
    expect(await reopened.read(savedWallpapersProvider.future), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(SavedWallpapers.storageKey), isEmpty);
  });

  test('saving two wallpapers quickly does not lose either selection',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(savedWallpapersProvider.future);
    final saved = container.read(savedWallpapersProvider.notifier);
    await Future.wait([saved.toggle('nature-1'), saved.toggle('wood-1')]);
    expect(await container.read(savedWallpapersProvider.future),
        {'nature-1', 'wood-1'});
  });
}
