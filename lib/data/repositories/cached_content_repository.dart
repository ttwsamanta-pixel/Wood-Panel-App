import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/content_models.dart';
import 'cache_refresh_bus.dart';
import 'content_repository.dart';

class CachedContentRepository implements ContentRepository {
  CachedContentRepository(
      {required this.inner, this.edition = 'europe', this.isActive});

  final String edition;
  final bool Function()? isActive;
  final Set<String> _refreshing = {};
  Future<void> _refreshOnce(String key, Future<void> Function() work) async {
    if (!_refreshing.add(key)) return;
    try {
      await work();
    } finally {
      _refreshing.remove(key);
    }
  }

  String get _prefix => 'content_cache_v2:$edition';
  static const _freshFor = Duration(minutes: 2);

  final ContentRepository inner;

  Future<void> refreshHome() async {
    await Future.wait([
      _refreshOnce(
          '$_prefix:latest_articles:1:12',
          () => _refreshArticleList(
              '$_prefix:latest_articles:1:12',
              () => inner.latestArticles(),
              '$_prefix:shared:latest_articles:1')),
      _refreshOnce('$_prefix:magazines_v2',
          () => _refreshMagazines('$_prefix:magazines_v2')),
      _refreshOnce('$_prefix:events', () => _refreshEvents('$_prefix:events')),
    ]);
  }

  @override
  Future<List<Article>> latestArticles({int page = 1, int perPage = 12}) {
    return _cachedArticleList(
      key: 'latest_articles:$page:$perPage',
      sharedKey: 'latest_articles:$page',
      fetch: () => inner.latestArticles(page: page, perPage: perPage),
    );
  }

  @override
  Future<List<Article>> articlesByCategory({
    required int categoryId,
    String? categoryName,
    int page = 1,
    int perPage = 12,
  }) {
    return _cachedArticleList(
      key: 'category:$categoryId:$page:$perPage',
      fetch: () => inner.articlesByCategory(
        categoryId: categoryId,
        categoryName: categoryName,
        page: page,
        perPage: perPage,
      ),
    );
  }

  @override
  Future<List<Article>> latestInterviews({int page = 1, int perPage = 12}) {
    return _cachedArticleList(
      key: 'interviews:$page:$perPage',
      fetch: () => inner.latestInterviews(page: page, perPage: perPage),
    );
  }

  @override
  Future<List<Article>> searchArticles(
    String query, {
    int page = 1,
    int perPage = 12,
  }) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return Future.value(const <Article>[]);
    }
    return _cachedArticleList(
      key: 'search:$normalized:$page:$perPage',
      fetch: () => inner.searchArticles(query, page: page, perPage: perPage),
    );
  }

  @override
  Future<Article> articleById(int id) async {
    final key = '$_prefix:article:$id';
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(key);
    if (cached != null) {
      if (!_isFresh(prefs, key)) {
        unawaited(_refreshOnce(key, () => _refreshSingleArticle(key, id)));
      }
      return Article.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    }
    final article = await inner.articleById(id);
    await _saveString(key, jsonEncode(article.toJson()));
    return article;
  }

  @override
  Future<List<MagazineIssue>> magazines() async {
    final key = '$_prefix:magazines_v2';
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(key);
    if (cached != null) {
      if (!_isFresh(prefs, key)) {
        unawaited(_refreshOnce(key, () => _refreshMagazines(key)));
      }
      return _decodeList(cached, MagazineIssue.fromJson);
    }
    final items = await inner.magazines();
    await _saveList(key, items.map((item) => item.toJson()).toList());
    return items;
  }

  @override
  Future<List<AppEvent>> events() async {
    final key = '$_prefix:events';
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(key);
    if (cached != null) {
      if (!_isFresh(prefs, key)) {
        unawaited(_refreshOnce(key, () => _refreshEvents(key)));
      }
      return _decodeList(cached, AppEvent.fromJson);
    }
    final items = await inner.events();
    await _saveList(key, items.map((item) => item.toJson()).toList());
    return items;
  }

  Future<List<Article>> _cachedArticleList({
    required String key,
    String? sharedKey,
    required Future<List<Article>> Function() fetch,
  }) async {
    final cacheKey = '$_prefix:$key';
    final sharedCacheKey =
        sharedKey == null ? null : '$_prefix:shared:$sharedKey';
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      if (!_isFresh(prefs, cacheKey)) {
        unawaited(_refreshOnce(cacheKey,
            () => _refreshArticleList(cacheKey, fetch, sharedCacheKey)));
      }
      return _decodeList(cached, Article.fromJson);
    }
    if (sharedCacheKey != null) {
      final sharedCached = prefs.getString(sharedCacheKey);
      if (sharedCached != null) {
        if (!_isFresh(prefs, sharedCacheKey)) {
          unawaited(_refreshOnce(cacheKey,
              () => _refreshArticleList(cacheKey, fetch, sharedCacheKey)));
        }
        return _decodeList(sharedCached, Article.fromJson);
      }
    }
    final items = await fetch();
    await _saveArticleList(cacheKey, items, sharedCacheKey);
    return items;
  }

  Future<void> _refreshArticleList(
    String key,
    Future<List<Article>> Function() fetch,
    String? sharedKey,
  ) async {
    try {
      final items = await fetch();
      {
        await _saveArticleList(key, items, sharedKey);
        if (isActive?.call() ?? true) {
          CacheRefreshBus.emit(CacheRefreshType.content);
        }
      }
    } on Object {
      // Keep the previous cache if background refresh fails.
    }
  }

  Future<void> _refreshSingleArticle(String key, int id) async {
    try {
      final article = await inner.articleById(id);
      await _saveString(key, jsonEncode(article.toJson()));
      if (isActive?.call() ?? true) {
        CacheRefreshBus.emit(CacheRefreshType.content);
      }
    } on Object {
      // Keep the previous cache if background refresh fails.
    }
  }

  Future<void> _refreshEvents(String key) async {
    try {
      final items = await inner.events();
      {
        await _saveList(key, items.map((item) => item.toJson()).toList());
        if (isActive?.call() ?? true) {
          CacheRefreshBus.emit(CacheRefreshType.content);
        }
      }
    } on Object {
      // Keep the previous cache if background refresh fails.
    }
  }

  Future<void> _refreshMagazines(String key) async {
    try {
      final items = await inner.magazines();
      {
        await _saveList(key, items.map((item) => item.toJson()).toList());
        if (isActive?.call() ?? true) {
          CacheRefreshBus.emit(CacheRefreshType.content);
        }
      }
    } on Object {
      // Keep the previous cache if background refresh fails.
    }
  }

  Future<void> _saveList(String key, List<Map<String, dynamic>> data) async {
    await _saveString(key, jsonEncode(data));
  }

  Future<void> _saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(isActive?.call() ?? true)) return;
    await prefs.setString(key, value);
    await prefs.setInt(
        _timestampKey(key), DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _saveArticleList(
    String key,
    List<Article> items,
    String? sharedKey,
  ) async {
    final data = items.map((item) => item.toJson()).toList();
    await _saveList(key, data);
    if (sharedKey != null) {
      await _saveList(sharedKey, data);
    }
  }

  List<T> _decodeList<T>(
    String value,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final decoded = jsonDecode(value) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
        .toList(growable: false);
  }

  bool _isFresh(SharedPreferences prefs, String key) {
    final savedAt = prefs.getInt(_timestampKey(key));
    if (savedAt == null) {
      return false;
    }
    final age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(savedAt),
    );
    return age < _freshFor;
  }

  String _timestampKey(String key) => '$key:saved_at';
}
