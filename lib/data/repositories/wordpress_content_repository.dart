import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../models/content_models.dart';
import '../models/news_category.dart';
import 'content_repository.dart';

class WordPressContentRepository implements ContentRepository {
  WordPressContentRepository(this._client);

  static const _interviewCategoryId = 34718;
  static const _listFields =
      'id,date,link,title,excerpt,author,featured_media,categories';

  final ApiClient _client;

  @override
  Future<List<Article>> latestArticles({int page = 1, int perPage = 12}) async {
    final data = await _client.get<List<dynamic>>(
      '/wp-json/wp/v2/posts',
      queryParameters: {
        '_fields': _listFields,
        'page': page,
        'per_page': perPage,
      },
    );
    return _listPostsFromJson(data);
  }

  @override
  Future<List<Article>> articlesByCategory({
    required int categoryId,
    String? categoryName,
    int page = 1,
    int perPage = 12,
  }) async {
    final data = await _client.get<List<dynamic>>(
      '/wp-json/wp/v2/posts',
      queryParameters: {
        '_fields': _listFields,
        'categories': categoryId,
        'page': page,
        'per_page': perPage,
      },
    );
    return _listPostsFromJson(data, fallbackCategoryName: categoryName);
  }

  @override
  Future<List<Article>> latestInterviews(
      {int page = 1, int perPage = 12}) async {
    final normalPosts = page == 1
        ? await _latestWordPressInterviews(perPage: perPage)
        : const <Article>[];
    final legacyPosts = await _legacyInterviewPosts(page: page);
    final merged = <Article>[];
    final seenUrls = <String>{};
    final seenTitles = <String>{};
    for (final article in [...normalPosts, ...legacyPosts]) {
      final urlKey = article.url.trim().toLowerCase();
      final titleKey = article.title
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
          .trim();
      if (seenUrls.add(urlKey) && seenTitles.add(titleKey)) {
        merged.add(article);
      }
    }
    return merged;
  }

  Future<List<Article>> _latestWordPressInterviews(
      {required int perPage}) async {
    try {
      return await articlesByCategory(
        categoryId: _interviewCategoryId,
        categoryName: 'Interview',
        page: 1,
        perPage: perPage,
      );
    } on Object {
      return const <Article>[];
    }
  }

  @override
  Future<Article> articleById(int id) async {
    final data = await _client.get<Map<String, dynamic>>(
      '/wp-json/wp/v2/posts/$id',
      queryParameters: {'_embed': true},
    );
    return _postFromJson(data);
  }

  @override
  Future<List<Article>> searchArticles(String query,
      {int page = 1, int perPage = 12}) async {
    if (query.trim().isEmpty) {
      return const [];
    }
    final data = await _client.get<List<dynamic>>(
      '/wp-json/wp/v2/posts',
      queryParameters: {
        '_fields': _listFields,
        'search': query.trim(),
        'page': page,
        'per_page': perPage,
      },
    );
    return _listPostsFromJson(data);
  }

  @override
  Future<List<MagazineIssue>> magazines() async => const [];

  @override
  Future<List<AppEvent>> events() async => const [];

  Future<List<Article>> _legacyInterviewPosts({required int page}) async {
    final path = page <= 1 ? '/interviews/' : '/interviews/page/$page/';
    final html = await _client.get<String>(path);
    final cards = RegExp(
      r'<div class="cat-post interview-post">([\s\S]*?)<a href="[^"]+" class="btn-read">',
    ).allMatches(html);
    final articles = <Article>[];
    var index = 0;
    for (final card in cards) {
      final article = _legacyInterviewFromHtml(
        card.group(1) ?? '',
        page,
        index++,
      );
      if (article != null) {
        articles.add(article);
      }
    }
    return articles;
  }

  Future<List<Article>> _listPostsFromJson(
    List<dynamic> data, {
    String? fallbackCategoryName,
  }) async {
    final posts = data.cast<Map<String, dynamic>>();
    final mediaById = await _mediaUrlsForPosts(posts);
    final authorsById = await _authorsForPosts(posts);
    return [
      for (final post in posts)
        _listPostFromJson(
          post,
          mediaById: mediaById,
          authorsById: authorsById,
          fallbackCategoryName: fallbackCategoryName,
        ),
    ];
  }

  Future<Map<int, String>> _mediaUrlsForPosts(
    List<Map<String, dynamic>> posts,
  ) async {
    final ids = posts
        .map((post) => (post['featured_media'] as num?)?.toInt() ?? 0)
        .where((id) => id > 0)
        .toSet();
    if (ids.isEmpty) {
      return const <int, String>{};
    }
    try {
      final media = await _client.get<List<dynamic>>(
        '/wp-json/wp/v2/media',
        queryParameters: {
          'include': ids.join(','),
          'per_page': ids.length.clamp(1, 100),
          '_fields': 'id,source_url',
        },
      );
      return {
        for (final item in media.cast<Map<String, dynamic>>())
          if (item['source_url'] is String)
            (item['id'] as num).toInt(): item['source_url'] as String,
      };
    } on Object {
      return const <int, String>{};
    }
  }

  Future<Map<int, ({String name, String avatarUrl})>> _authorsForPosts(
    List<Map<String, dynamic>> posts,
  ) async {
    final ids = posts
        .map((post) => (post['author'] as num?)?.toInt() ?? 0)
        .where((id) => id > 0)
        .toSet();
    if (ids.isEmpty) {
      return const <int, ({String name, String avatarUrl})>{};
    }
    try {
      final users = await _client.get<List<dynamic>>(
        '/wp-json/wp/v2/users',
        queryParameters: {
          'include': ids.join(','),
          'per_page': ids.length.clamp(1, 100),
          '_fields': 'id,name,avatar_urls',
        },
      );
      return {
        for (final item in users.cast<Map<String, dynamic>>())
          (item['id'] as num).toInt(): (
            name: (item['name'] as String?) ?? 'Wood & Panel',
            avatarUrl: _authorAvatar(item),
          ),
      };
    } on Object {
      return const <int, ({String name, String avatarUrl})>{};
    }
  }

  Article _listPostFromJson(
    Map<String, dynamic> json, {
    required Map<int, String> mediaById,
    required Map<int, ({String name, String avatarUrl})> authorsById,
    String? fallbackCategoryName,
  }) {
    final title = _rendered(json['title']);
    final excerpt = _stripHtml(_rendered(json['excerpt']));
    final link = (json['link'] as String?) ?? AppConfig.wordpressBaseUrl;
    final mediaId = (json['featured_media'] as num?)?.toInt() ?? 0;
    final authorId = (json['author'] as num?)?.toInt() ?? 0;
    final author = authorsById[authorId];

    return Article(
      id: (json['id'] as num?)?.toInt() ?? 0,
      category: _categoryNameFromIds(json['categories']) ??
          fallbackCategoryName ??
          'Latest',
      title: _decodeHtml(title),
      excerpt: _decodeHtml(excerpt),
      imageUrl: mediaById[mediaId] ?? _fallbackImage,
      date:
          DateTime.tryParse((json['date'] as String?) ?? '') ?? DateTime.now(),
      readingMinutes: _listReadingMinutes(title: title, excerpt: excerpt),
      author: author?.name ?? 'Wood & Panel',
      authorAvatarUrl: author?.avatarUrl ?? '',
      url: link,
      html: '',
    );
  }

  Article? _legacyInterviewFromHtml(String html, int page, int index) {
    final url = _decodeHtml(_firstMatch(html, r'<a href="([^"]+)">') ?? '');
    final title = _decodeHtml(_stripHtml(_firstMatch(
          html,
          r'<h3>([\s\S]*?)</h3>',
        ) ??
        ''));
    if (url.isEmpty || title.isEmpty || url.endsWith('/feed/')) {
      return null;
    }
    final excerpt = _decodeHtml(_stripHtml(_firstMatch(
          html,
          r'<p>([\s\S]*?)</p>',
        ) ??
        ''));
    final imageUrl = _decodeHtml(
      _firstMatch(html, r'data-breeze="([^"]+)"') ??
          _firstMatch(html, r'<img[^>]+src="([^"]+)"') ??
          '',
    );
    final fallbackId = -url.hashCode.abs();
    return Article(
      id: fallbackId,
      category: 'Interview',
      title: title,
      excerpt: excerpt,
      imageUrl: imageUrl.isEmpty
          ? 'https://www.woodandpanel.com/wp-content/uploads/2021/08/app-logo-big.jpg'
          : imageUrl,
      date: DateTime.now().subtract(Duration(days: ((page - 1) * 12) + index)),
      readingMinutes: 5,
      author: 'Wood & Panel',
      url: url,
      html: '',
    );
  }

  Article _postFromJson(Map<String, dynamic> json) {
    final title = _rendered(json['title']);
    final excerpt = _stripHtml(_rendered(json['excerpt']));
    final content = _rendered(json['content']);
    final link = (json['link'] as String?) ?? AppConfig.wordpressBaseUrl;
    final embedded = json['_embedded'] as Map<String, dynamic>?;
    final media =
        (embedded?['wp:featuredmedia'] as List?)?.cast<Map<String, dynamic>>();
    final terms = (embedded?['wp:term'] as List?)?.cast<List<dynamic>>();
    final authors =
        (embedded?['author'] as List?)?.cast<Map<String, dynamic>>();

    return Article(
      id: (json['id'] as num?)?.toInt() ?? 0,
      category: _categoryName(terms) ?? 'Latest',
      title: _decodeHtml(title),
      excerpt: _decodeHtml(excerpt),
      imageUrl: _featuredImage(media),
      date:
          DateTime.tryParse((json['date'] as String?) ?? '') ?? DateTime.now(),
      readingMinutes: _readingMinutes(content),
      author: (_firstOrNull(authors)?['name'] as String?) ?? 'Wood & Panel',
      authorAvatarUrl: _authorAvatar(_firstOrNull(authors)),
      url: link,
      html: content,
    );
  }

  String _rendered(Object? value) {
    if (value is Map<String, dynamic>) {
      return (value['rendered'] as String?) ?? '';
    }
    return '';
  }

  String? _categoryName(List<List<dynamic>>? terms) {
    if (terms == null || terms.isEmpty || terms.first.isEmpty) {
      return null;
    }
    final first = terms.first.first;
    if (first is Map<String, dynamic>) {
      return first['name'] as String?;
    }
    return null;
  }

  String? _categoryNameFromIds(Object? value) {
    if (value is! List || value.isEmpty) {
      return null;
    }
    for (final id in value.whereType<num>()) {
      final categoryId = id.toInt();
      final knownCategory = NewsCategory.all.where(
        (category) => category.id == categoryId,
      );
      if (knownCategory.isNotEmpty) {
        return knownCategory.first.name;
      }
    }
    return null;
  }

  String _featuredImage(List<Map<String, dynamic>>? media) {
    final source = _firstOrNull(media)?['source_url'] as String?;
    return source ?? _fallbackImage;
  }

  String get _fallbackImage =>
      'https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?auto=format&fit=crop&w=1200&q=80';

  String _authorAvatar(Map<String, dynamic>? author) {
    final avatars = author?['avatar_urls'];
    if (avatars is Map<String, dynamic>) {
      return (avatars['96'] ?? avatars['48'] ?? avatars['24'] ?? '') as String;
    }
    return '';
  }

  int _readingMinutes(String html) {
    final words = _stripHtml(html)
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
    return (words / 220).ceil().clamp(1, 30);
  }

  int _listReadingMinutes({required String title, required String excerpt}) {
    final words = '$title $excerpt'
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
    return (words / 90).ceil().clamp(4, 8);
  }

  String _stripHtml(String html) => html
      .replaceAll(RegExp('<[^>]*>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String _decodeHtml(String value) {
    var decoded = value;
    for (var pass = 0; pass < 2; pass++) {
      decoded = decoded
          .replaceAll('&amp;', '&')
          .replaceAll('&#038;', '&')
          .replaceAll('&#8217;', "'")
          .replaceAll('&#8216;', "'")
          .replaceAll('&rsquo;', "'")
          .replaceAll('&lsquo;', "'")
          .replaceAll('&quot;', '"')
          .replaceAll('&#8220;', '"')
          .replaceAll('&#8221;', '"')
          .replaceAll('&ldquo;', '"')
          .replaceAll('&rdquo;', '"')
          .replaceAll('&#8211;', '-')
          .replaceAll('&#8212;', '-')
          .replaceAll('&ndash;', '-')
          .replaceAll('&mdash;', '-')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&hellip;', '...')
          .replaceAll('&auml;', 'ä')
          .replaceAll('&Auml;', 'Ä')
          .replaceAll('&eacute;', 'é')
          .replaceAll('&Eacute;', 'É')
          .replaceAll('&iacute;', 'í')
          .replaceAll('&Iacute;', 'Í')
          .replaceAll('&oacute;', 'ó')
          .replaceAll('&Oacute;', 'Ó')
          .replaceAll('&ouml;', 'ö')
          .replaceAll('&Ouml;', 'Ö')
          .replaceAll('&uuml;', 'ü')
          .replaceAll('&Uuml;', 'Ü')
          .replaceAll('&ccedil;', 'ç')
          .replaceAll('&Ccedil;', 'Ç')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>');
    }
    return decoded;
  }

  String? _firstMatch(String value, String pattern) {
    return RegExp(pattern, caseSensitive: false)
        .firstMatch(value)
        ?.group(1)
        ?.trim();
  }

  T? _firstOrNull<T>(List<T>? items) {
    if (items == null || items.isEmpty) {
      return null;
    }
    return items.first;
  }
}
