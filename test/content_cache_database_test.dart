import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wood_panel_app/data/repositories/content_cache_database.dart';
import 'package:wood_panel_app/data/repositories/cached_content_repository.dart';
import 'package:wood_panel_app/data/repositories/content_repository.dart';
import 'package:wood_panel_app/data/models/content_models.dart';

class Source implements ContentRepository {
  final pending = Completer<List<Article>>();
  int calls = 0;
  @override
  Future<List<Article>> latestArticles({int page = 1, int perPage = 12}) {
    calls++;
    return pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  sqfliteFfiInit();
  late Directory dir;
  late ContentCacheDatabase db;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('wp-cache-');
    db = ContentCacheDatabase(
        factory: databaseFactoryFfi, path: '${dir.path}/cache.db');
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });
  test('Migration survives reopen, preserves edition isolation and user data',
      () async {
    const eu = 'content_cache_v2:europe:article:1';
    const us = 'content_cache_v2:usa:article:1';
    SharedPreferences.setMockInitialValues({
      eu: '{"title":"Europe"}',
      '$eu:saved_at': 123,
      us: '{"title":"USA"}',
      'app_downloads_v1': '[]',
      'theme': 'dark'
    });
    expect((await db.read(eu))!.savedAt, 123);
    expect((await db.read(us))!.payload, contains('USA'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(eu), false);
    expect(prefs.getString('theme'), 'dark');
    expect(prefs.getString('app_downloads_v1'), '[]');
    await db.close();
    expect((await db.read(eu))!.payload, contains('Europe'));
  });
  test('Stale content returns without waiting, one refresh updates SQLite',
      () async {
    const key = 'content_cache_v2:europe:latest_articles:1:12';
    SharedPreferences.setMockInitialValues({key: '[{"id":1,"title":"Saved"}]'});
    final source = Source();
    final repo = CachedContentRepository(inner: source, cache: db);
    expect(
        (await repo.latestArticles().timeout(const Duration(seconds: 2)))
            .single
            .title,
        'Saved');
    expect((await repo.latestArticles()).single.title, 'Saved');
    expect(source.calls, 1);
    source.pending.complete([
      Article.fromJson({'id': 2, 'title': 'Updated'})
    ]);
    for (var i = 0; i < 50; i++) {
      if ((await db.read(key))!.payload.contains('Updated')) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(jsonDecode((await db.read(key))!.payload)[0]['title'], 'Updated');
  });
  test('Offline refresh failure keeps saved content usable', () async {
    const key = 'content_cache_v2:usa:latest_articles:1:12';
    SharedPreferences.setMockInitialValues(
        {key: '[{"id":1,"title":"Offline"}]'});
    final source = Source();
    final repo =
        CachedContentRepository(inner: source, cache: db, edition: 'usa');
    expect((await repo.latestArticles()).single.title, 'Offline');
    source.pending.completeError(StateError('offline'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect((await db.read(key))!.payload, contains('Offline'));
  });
}
