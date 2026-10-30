import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wood_panel_app/core/edition/edition.dart';
import 'package:wood_panel_app/core/network/api_client.dart';
import 'package:wood_panel_app/data/models/content_models.dart';
import 'package:wood_panel_app/data/repositories/bookmark_repository.dart';
import 'package:wood_panel_app/data/repositories/cached_content_repository.dart';
import 'package:wood_panel_app/data/repositories/download_repository.dart';
import 'package:wood_panel_app/data/repositories/mock_content_repository.dart';

class _EditionSource extends MockContentRepository {
  _EditionSource(this.title);
  final String title;
  int calls = 0;
  @override
  Future<List<Article>> latestArticles({int page = 1, int perPage = 12}) async {
    calls++;
    return [
      Article.fromJson({'id': 1, 'title': title})
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('new process starts Europe, existing runtime retains USA', () {
    final runtime = ProviderContainer();
    expect(runtime.read(editionProvider), Edition.europe);
    runtime.read(editionProvider.notifier).state = Edition.usa;
    expect(runtime.read(editionProvider), Edition.usa);
    runtime.dispose();
    final restarted = ProviderContainer();
    addTearDown(restarted.dispose);
    expect(restarted.read(editionProvider), Edition.europe);
  });

  test('only trusted regional hosts select an edition', () {
    expect(Edition.forHost('www.woodandpanel.us'), Edition.usa);
    expect(Edition.forHost('woodandpanel.com'), Edition.europe);
    expect(Edition.forHost('woodandpanel.us.example.com'), isNull);
    expect(Edition.forHost('fakewoodandpanel.us'), isNull);
  });

  test('config rejects another edition and unsupported schema', () {
    expect(
        () => EditionConfig.fromJson(
            Edition.usa, {'schema_version': 1, 'edition': 'europe'}),
        throwsFormatException);
    expect(
        () => EditionConfig.fromJson(
            Edition.usa, {'schema_version': 2, 'edition': 'usa'}),
        throwsFormatException);
  });

  test('config retains independent category order, sections and branding', () {
    final config = EditionConfig.fromJson(Edition.usa, {
      'schema_version': 1,
      'edition': 'usa',
      'branding': {
        'confirmed': true,
        'primary': '#123456',
        'secondary': '#234567'
      },
      'home_categories': [
        {'id': 8, 'name': 'Home'},
        {'id': 2, 'name': 'Second'}
      ],
      'explore_categories': [
        {'id': 11, 'name': 'Explore'}
      ],
      'home_sections': ['videos', 'latest'],
    });
    expect(config.primary, const Color(0xff123456));
    expect(config.homeCategories.map((c) => c.id), [8, 2]);
    expect(config.categories.map((c) => c.id), [11]);
    expect(config.sections, ['videos', 'latest']);
  });

  test('legacy bookmarks migrate only into Europe, once', () async {
    SharedPreferences.setMockInitialValues({
      'bookmarked_article_ids': ['42']
    });
    final europe = BookmarkRepository();
    final usa = BookmarkRepository(edition: 'usa');
    expect(await europe.articleIds(), {42});
    expect(await usa.articleIds(), isEmpty);
    await usa.setArticleBookmark(42, true);
    await europe.setArticleBookmark(42, false);
    expect(await BookmarkRepository().articleIds(), isEmpty);
    expect(await usa.articleIds(), {42});
  });

  test('same IDs in separate edition caches never collide', () async {
    final europeSource = _EditionSource('Europe article');
    final usaSource = _EditionSource('USA article');
    final europe = CachedContentRepository(inner: europeSource);
    final usa = CachedContentRepository(inner: usaSource, edition: 'usa');
    expect((await europe.latestArticles()).single.title, 'Europe article');
    expect((await usa.latestArticles()).single.title, 'USA article');
    expect((await europe.latestArticles()).single.title, 'Europe article');
    expect(europeSource.calls, 1);
    expect(usaSource.calls, 1);
  });

  test('BOM JSON decodes and simultaneous GETs share one request', () async {
    var calls = 0;
    final dio = Dio();
    dio.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      handler.resolve(Response(
          requestOptions: options, data: '\uFEFF[{"id":1}]', statusCode: 200));
    }));
    final api = ApiClient(dio: dio);
    final values = await Future.wait(
        [api.get<List<dynamic>>('/posts'), api.get<List<dynamic>>('/posts')]);
    expect(values.first.first['id'], 1);
    expect(calls, 1);
    dio.close();
  });

  test('legacy downloaded files retain edition identity', () {
    expect(
        DownloadedFile.fromJson({'url': 'https://www.woodandpanel.com/a.pdf'})
            .edition,
        'europe');
    final usa =
        DownloadedFile.fromJson({'url': 'https://www.woodandpanel.us/a.pdf'});
    expect(DownloadedFile.fromJson(usa.toJson()).edition, 'usa');
  });

  test('preloader configuration is parsed with branding colours', () {
    final config = EditionConfig.fromJson(Edition.usa, {
      'schema_version': 1,
      'edition': 'usa',
      'branding': {
        'confirmed': true,
        'preloader_url': 'https://example.com/loader.png',
        'preloader_color': '#123456'
      },
    });
    expect(config.preloaderUrl, 'https://example.com/loader.png');
    expect(config.preloaderColor, const Color(0xff123456));
  });

  test('simultaneous stale cache reads start one background refresh', () async {
    final source = _EditionSource('Updated');
    final repository = CachedContentRepository(inner: source);
    await repository.latestArticles();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        'content_cache_v2:europe:latest_articles:1:12:saved_at', 0);
    await Future.wait(List.generate(5, (_) => repository.latestArticles()));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(source.calls, 2);
  });
}
