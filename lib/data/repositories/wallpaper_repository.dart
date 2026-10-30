import 'dart:io';
import 'package:flutter/services.dart';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/edition/edition.dart';

class Wallpaper {
  const Wallpaper(this.id, this.title, this.category, this.photo);

  final String id;
  final String title;
  final String category;
  final String photo;

  String imageUrl(int width) => photo.startsWith('https://')
      ? photo
      : Uri.https('images.unsplash.com', '/$photo', {
          'fm': 'jpg',
          'fit': 'max',
          'w': '$width',
          'q': '85',
        }).toString();
}

const wallpaperCategories = [
  'Nature',
  'Wood textures',
  'Furniture',
  'Interior',
  'Industry',
  'Architecture',
];

// Starter collection until the app dashboard supplies the wallpaper catalogue.
const wallpaperCatalog = [
  Wallpaper('default-grain', 'Walnut grain', 'Wood textures',
      'assets/wallpapers/grain.png'),
  Wallpaper('default-forest', 'Forest light', 'Nature',
      'assets/wallpapers/forest.png'),
  Wallpaper('default-interior', 'Warm oak', 'Interior',
      'assets/wallpapers/interior.png'),
];

final wallpaperCatalogProvider = Provider<List<Wallpaper>>((ref) {
  final config = ref.watch(activeConfigProvider);
  return [
    if (config.defaultWallpapers) ...wallpaperCatalog,
    ...config.wallpapers.map((item) => Wallpaper(
        '${config.edition.name}-${item['id']}',
        item['title']!,
        item['category']!,
        item['image_url']!)),
  ];
});

final savedWallpapersProvider =
    AsyncNotifierProvider<SavedWallpapers, Set<String>>(SavedWallpapers.new);

class SavedWallpapers extends AsyncNotifier<Set<String>> {
  static const storageKey = 'saved_wallpapers_v1';
  Future<void> _pending = Future.value();

  @override
  Future<Set<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(storageKey) ?? []).toSet();
  }

  Future<void> toggle(String id) {
    final operation = _pending.then((_) => _toggle(id));
    _pending = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _toggle(String id) async {
    final previous = await future;
    final next = {...previous};
    if (!next.add(id)) next.remove(id);
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setStringList(storageKey, next.toList())) {
      throw const FileSystemException('Could not save wallpaper preference');
    }
    state = AsyncData(next);
  }
}

class WallpaperRepository {
  WallpaperRepository()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 45),
        ));

  final Dio _dio;

  Future<File> temporaryImage(
    Wallpaper wallpaper, {
    required CancelToken cancelToken,
    required ProgressCallback onProgress,
  }) async {
    final base = await getTemporaryDirectory();
    final directory = await Directory('${base.path}/wallpaper_exports')
        .create(recursive: true);
    // Expire exports from previous share sessions; never retain originals as gallery cache.
    await for (final entry in directory.list()) {
      if (entry is File &&
          DateTime.now().difference((await entry.stat()).modified).inDays >=
              1) {
        await entry.delete();
      }
    }
    final file = File(
        '${directory.path}/${wallpaper.id}_${DateTime.now().microsecondsSinceEpoch}.${wallpaper.photo.startsWith('assets/') ? 'png' : 'jpg'}');
    try {
      if (wallpaper.photo.startsWith('assets/')) {
        final bytes = await rootBundle.load(wallpaper.photo);
        await file.writeAsBytes(
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
        onProgress(bytes.lengthInBytes, bytes.lengthInBytes);
        return file;
      }
      await _dio.download(wallpaper.imageUrl(2400), file.path,
          cancelToken: cancelToken, onReceiveProgress: onProgress);
      return file;
    } catch (_) {
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }
}
