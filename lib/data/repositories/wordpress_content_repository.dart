import '../../core/edition/edition.dart';
import 'package:html/parser.dart' as html_parser;
import '../../core/network/api_client.dart';
import '../models/content_models.dart';

import 'content_repository.dart';

class WordPressContentRepository implements ContentRepository {
  WordPressContentRepository(this._client, {required this.config});
  final EditionConfig config;

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
    final normalPosts =
        await _latestWordPressInterviews(perPage: perPage, page: page);
    final legacyPosts =
        await _legacyInterviewPosts(page: page).catchError((_) => <Article>[]);
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
      {required int perPage, required int page}) async {
    try {
      final terms = await _client
          .get<List<dynamic>>('/wp-json/wp/v2/categories', queryParameters: {
        'slug': 'interview,interviews',
        '_fields': 'id',
        'per_page': 100
      });
      final ids = terms.map((term) => term['id']).whereType<num>().join(',');
      if (ids.isEmpty) return const [];
      final posts = await _client.get<List<dynamic>>('/wp-json/wp/v2/posts',
          queryParameters: {
            'categories': ids,
            '_fields': _listFields,
            'page': page,
            'per_page': perPage
          });
      return await _listPostsFromJson(posts, fallbackCategoryName: 'Interview');
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
  Future<List<MagazineIssue>> magazines() async {
    if (config.managed) {
      return (await _managedItems('magazines'))
          .map(MagazineIssue.fromJson)
          .toList();
    }
    final issuesByUrl = <String, MagazineIssue>{};
    for (var year = DateTime.now().year; year >= 2022; year--) {
      try {
        final html = await _client.get<String>('/archive/archive-$year/');
        for (final issue in _magazinesFromArchiveHtml(html, year)) {
          issuesByUrl[issue.readUrl] = issue;
        }
      } on Object {
        // Keep loading other years if one archive page is temporarily blocked.
      }
    }
    final issues = issuesByUrl.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return issues;
  }

  @override
  Future<List<AppEvent>> events() async {
    if (config.managed) {
      return (await _managedItems('events')).map(AppEvent.fromJson).toList();
    }
    final eventsByKey = <String, AppEvent>{};
    final requests = [
      (path: '/events/', query: null),
      (path: '/events/list/', query: {'eventDisplay': 'past'}),
    ];
    for (final request in requests) {
      try {
        final html = await _client.get<String>(
          request.path,
          queryParameters: request.query,
        );
        for (final event in _eventsFromHtml(html)) {
          final key = event.url.isNotEmpty
              ? event.url.toLowerCase()
              : event.title.toLowerCase();
          eventsByKey[key] = event;
        }
      } on Object {
        // Keep the event feed usable if one view is blocked or temporarily down.
      }
    }
    return eventsByKey.values.toList();
  }

  Future<List<Map<String, dynamic>>> _managedItems(String kind) async {
    final items = <Map<String, dynamic>>[];
    for (var page = 1; page <= 100; page++) {
      final data = await _client.get<Map<String, dynamic>>(
          '/wp-json/wood-panel-app/v1/$kind',
          queryParameters: {'page': page, 'per_page': 50});
      if (data['edition'] != config.edition.name) {
        throw const FormatException('Wrong content edition');
      }
      items.addAll((data['items'] as List).cast<Map<String, dynamic>>());
      if (page >= ((data['total_pages'] as num?)?.toInt() ?? 1)) break;
    }
    return items;
  }

  Future<List<Article>> _legacyInterviewPosts({required int page}) async {
    final path = page <= 1 ? '/interviews/' : '/interviews/page/$page/';
    final html = await _client.get<String>(path);
    final cards = html_parser
        .parse(html)
        .querySelectorAll('.cat-post.interview-post, .wpusa-interview-item');
    final articles = <Article>[];
    var index = 0;
    for (final card in cards) {
      final article = _legacyInterviewFromHtml(
        card.outerHtml,
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
    final link = (json['link'] as String?) ?? _client.baseUrl;
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
    final card = html_parser.parseFragment(html);
    final url = card.querySelector('a[href]')?.attributes['href'] ?? '';
    final title = card.querySelector('h3')?.text.trim() ?? '';
    if (url.isEmpty || title.isEmpty || url.endsWith('/feed/')) {
      return null;
    }
    final excerpt = _decodeHtml(_stripHtml(_firstMatch(
          html,
          r'<p>([\s\S]*?)</p>',
        ) ??
        ''));
    final image = card.querySelector('img');
    final imageUrl = image?.attributes['data-src'] ??
        image?.attributes['data-breeze'] ??
        image?.attributes['src'] ??
        '';
    final fallbackId = -url.hashCode.abs();
    return Article(
      id: fallbackId,
      category: 'Interview',
      title: title,
      excerpt: excerpt,
      imageUrl: imageUrl.isEmpty ? config.logoUrl : imageUrl,
      date: DateTime.now().subtract(Duration(days: ((page - 1) * 12) + index)),
      readingMinutes: 5,
      author: 'Wood & Panel',
      url: url,
      html: '',
    );
  }

  List<MagazineIssue> _magazinesFromArchiveHtml(String html, int year) {
    final cards = RegExp(
      r'<div class="archive-card">([\s\S]*?)<a href="(https://[^/]+/flipbooks/[^"]+)"[^>]*class="read-btn">Read Online</a>',
      caseSensitive: false,
    ).allMatches(html);
    return [
      for (final card in cards)
        if (_magazineFromArchiveCard(card, year) case final issue?) issue,
    ];
  }

  MagazineIssue? _magazineFromArchiveCard(RegExpMatch card, int year) {
    final body = card.group(1) ?? '';
    final readUrl = _decodeHtml(card.group(2) ?? '');
    final title = _decodeHtml(_stripHtml(_firstMatch(
          body,
          r'<h2>([\s\S]*?)</h2>',
        ) ??
        ''));
    final coverUrl = _decodeHtml(
      _firstMatch(body, r'data-breeze="([^"]+)"') ??
          _firstMatch(body, r'<img[^>]+src="([^"]+)"') ??
          '',
    );
    if (readUrl.isEmpty || title.isEmpty || coverUrl.startsWith('data:')) {
      return null;
    }
    final topics = RegExp(
      r'<li>([\s\S]*?)</li>',
      caseSensitive: false,
    )
        .allMatches(body)
        .map((match) => _decodeHtml(_stripHtml(match.group(1) ?? '')))
        .where((item) => item.isNotEmpty)
        .toList();
    return MagazineIssue(
      id: _magazineId(title, year),
      title: _titleCaseIssue(title),
      coverUrl: coverUrl,
      date: _issueDate(title, year),
      description: topics.isEmpty
          ? 'Wood & Panel digital magazine issue.'
          : topics.join(', '),
      fileSize: 'Online issue',
      readUrl: readUrl,
      pdfUrl: _pdfUrlForFlipbook(readUrl),
    );
  }

  List<AppEvent> _eventsFromHtml(String html) {
    final articles = RegExp(
      r'<article[^>]+class="[^"]*tribe-events-calendar-(?:list|latest-past)__event\b[^"]*"[^>]*>([\s\S]*?)</article>',
      caseSensitive: false,
    ).allMatches(html);
    return [
      for (final article in articles)
        if (_eventFromHtml(article.group(1) ?? '') case final event?) event,
    ];
  }

  AppEvent? _eventFromHtml(String html) {
    final title = _decodeHtml(_stripHtml(_firstMatch(
          html,
          r'<a[^>]+class="[^"]*event-title-link[^"]*"[^>]*>([\s\S]*?)</a>',
        ) ??
        ''));
    final url = _decodeHtml(_firstMatch(
          html,
          r'<a[^>]+href="([^"]+)"[^>]+class="[^"]*event-title-link[^"]*"',
        ) ??
        _firstMatch(
          html,
          r'<a[^>]+class="[^"]*event-title-link[^"]*"[^>]+href="([^"]+)"',
        ) ??
        '');
    if (title.isEmpty) {
      return null;
    }
    final date = _decodeHtml(_stripHtml(_firstMatch(
          html,
          r'<time[^>]+class="[^"]*event-datetime[^"]*"[^>]*>([\s\S]*?)</time>',
        ) ??
        ''));
    final venueTitle = _decodeHtml(_stripHtml(_firstMatch(
          html,
          r'<span[^>]+class="[^"]*event-venue-title[^"]*"[^>]*>([\s\S]*?)</span>',
        ) ??
        ''));
    final venueAddress = _decodeHtml(_stripHtml(_firstMatch(
          html,
          r'<span[^>]+class="[^"]*event-venue-address[^"]*"[^>]*>([\s\S]*?)</span>',
        ) ??
        ''));
    final location = [
      if (venueTitle.isNotEmpty) venueTitle,
      if (venueAddress.isNotEmpty) venueAddress,
    ].join(', ');
    final imageUrl = _decodeHtml(
      _firstMatch(html, r'data-breeze="([^"]+)"') ??
          _firstMatch(html, r'<img[^>]+src="([^"]+)"') ??
          _fallbackImage,
    );
    return AppEvent(
      title: title,
      date: date.isEmpty ? 'Event date to be announced' : date,
      location: location.isEmpty ? 'Venue to be announced' : location,
      imageUrl: imageUrl.startsWith('data:') ? _fallbackImage : imageUrl,
      url: url,
    );
  }

  String _pdfUrlForFlipbook(String readUrl) {
    final uri = Uri.tryParse(readUrl);
    if (uri == null) {
      return '';
    }
    final path = uri.path.endsWith('/index.html')
        ? uri.path.substring(0, uri.path.length - 'index.html'.length)
        : uri.path.endsWith('/')
            ? uri.path
            : '${uri.path}/';
    return uri.replace(path: '${path}offline/download.pdf').toString();
  }

  int _magazineId(String title, int year) {
    final date = _issueDate(title, year);
    return (date.year * 100) + date.month;
  }

  DateTime _issueDate(String title, int year) {
    final normalized = title
        .toUpperCase()
        .replaceAll('&NDASH;', ' ')
        .replaceAll('–', ' ')
        .replaceAll('-', ' ');
    final months = <String, int>{
      'JAN': 1,
      'JANUARY': 1,
      'FEB': 2,
      'FEBRUARY': 2,
      'MAR': 3,
      'MARCH': 3,
      'APR': 4,
      'APRIL': 4,
      'MAY': 5,
      'JUNE': 6,
      'JUL': 7,
      'JULY': 7,
      'AUG': 8,
      'AUGUST': 8,
      'SEP': 9,
      'SEPT': 9,
      'SEPTEMBER': 9,
      'OCT': 10,
      'OCTOBER': 10,
      'NOV': 11,
      'NOVEMBER': 11,
      'DEC': 12,
      'DECEMBER': 12,
    };
    final found = RegExp(r'[A-Z]+')
        .allMatches(normalized)
        .map((match) => months[match.group(0)])
        .whereType<int>()
        .toList();
    return DateTime(year, found.isEmpty ? 1 : found.last, 1);
  }

  String _titleCaseIssue(String title) {
    return title
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase()
        .split(' ')
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  Article _postFromJson(Map<String, dynamic> json) {
    final title = _rendered(json['title']);
    final excerpt = _stripHtml(_rendered(json['excerpt']));
    final content = _rendered(json['content']);
    final link = (json['link'] as String?) ?? _client.baseUrl;
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
      final knownCategory = config.categories.where(
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
