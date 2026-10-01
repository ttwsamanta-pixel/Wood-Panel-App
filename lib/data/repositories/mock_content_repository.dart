import '../models/content_models.dart';
import 'content_repository.dart';

class MockContentRepository implements ContentRepository {
  @override
  Future<List<Article>> latestArticles({int page = 1, int perPage = 12}) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final start = (page - 1) * perPage;
    if (start >= _articles.length) {
      return const [];
    }
    final end = (start + perPage).clamp(0, _articles.length);
    return _articles.sublist(start, end);
  }

  @override
  Future<List<Article>> articlesByCategory({
    required int categoryId,
    String? categoryName,
    int page = 1,
    int perPage = 12,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final normalized = (categoryName ?? '').toLowerCase().trim();
    final matches = normalized.isEmpty
        ? const <Article>[]
        : _articles
            .where(
              (article) =>
                  article.category.toLowerCase().contains(normalized) ||
                  normalized.contains(article.category.toLowerCase()),
            )
            .toList();
    final source = matches.isEmpty ? _articles : matches;
    final start = (page - 1) * perPage;
    if (start >= source.length) {
      return const [];
    }
    final end = (start + perPage).clamp(0, source.length);
    return source.sublist(start, end);
  }

  @override
  Future<List<Article>> latestInterviews(
      {int page = 1, int perPage = 12}) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final interviews = _articles
        .where((article) =>
            article.category.toLowerCase().contains('interview') ||
            article.title.toLowerCase().contains('interview'))
        .toList();
    final source = interviews.isEmpty ? _articles : interviews;
    final start = (page - 1) * perPage;
    if (start >= source.length) {
      return const [];
    }
    final end = (start + perPage).clamp(0, source.length);
    return source.sublist(start, end);
  }

  @override
  Future<Article> articleById(int id) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return _articles.firstWhere((article) => article.id == id,
        orElse: () => _articles.first);
  }

  @override
  Future<List<Article>> searchArticles(String query,
      {int page = 1, int perPage = 12}) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final normalized = query.toLowerCase().trim();
    if (normalized.isEmpty) {
      return const [];
    }
    return _articles
        .where(
          (article) =>
              article.title.toLowerCase().contains(normalized) ||
              article.excerpt.toLowerCase().contains(normalized) ||
              article.category.toLowerCase().contains(normalized),
        )
        .toList();
  }

  @override
  Future<List<MagazineIssue>> magazines() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _magazines;
  }

  @override
  Future<List<AppEvent>> events() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _events;
  }
}

final mockContentRepository = MockContentRepository();

final _articles = <Article>[
  Article(
    id: 1,
    category: 'Panel Industry',
    title: 'India’s Panel Industry Eyes Strong Growth in 2025',
    excerpt:
        'Industry demand is expanding as furniture, interiors, and construction projects continue to scale.',
    imageUrl:
        'https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?auto=format&fit=crop&w=1200&q=80',
    date: DateTime(2025, 9, 24),
    readingMinutes: 4,
    author: 'Wood & Panel Desk',
    url: 'https://www.woodandpanel.com/',
    html:
        '<p>The Indian panel industry is witnessing a new phase of growth, driven by modern furniture manufacturing, architectural interiors, and improved supply chains.</p><h2>Market outlook</h2><p>Manufacturers are focusing on better finishes, sustainable sourcing, and technology-led production.</p><blockquote>Quality, design, and responsible sourcing are becoming decisive advantages.</blockquote>',
  ),
  Article(
    id: 2,
    category: 'Sustainability',
    title: 'Sustainable Wood Sourcing Gains Momentum',
    excerpt:
        'Certified materials and transparent sourcing practices are moving from preference to expectation.',
    imageUrl:
        'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80',
    date: DateTime(2025, 9, 20),
    readingMinutes: 5,
    author: 'Editorial Team',
    url: 'https://www.woodandpanel.com/',
    html:
        '<p>Global buyers increasingly expect traceable raw materials and documented sustainability practices.</p>',
  ),
  Article(
    id: 3,
    category: 'Machinery',
    title: 'New MDF Plant Sets Benchmark in Sustainability',
    excerpt:
        'A new generation of production facilities is improving efficiency and reducing waste.',
    imageUrl:
        'https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=1200&q=80',
    date: DateTime(2025, 9, 18),
    readingMinutes: 3,
    author: 'Industry Bureau',
    url: 'https://www.woodandpanel.com/',
    html:
        '<p>Automation, energy optimization, and improved material recovery are reshaping MDF production.</p>',
  ),
  Article(
    id: 4,
    category: 'Interviews',
    title: 'In Conversation with Rohit Agarwal',
    excerpt:
        'A leader’s view on technology, exports, and the next decade of panels.',
    imageUrl:
        'https://images.unsplash.com/photo-1560250097-0b93528c311a?auto=format&fit=crop&w=1200&q=80',
    date: DateTime(2025, 9, 15),
    readingMinutes: 6,
    author: 'Wood & Panel',
    url: 'https://www.woodandpanel.com/',
    html:
        '<p>In this interview, Rohit Agarwal discusses growth opportunities and the importance of international quality standards.</p>',
  ),
];

final _magazines = <MagazineIssue>[
  MagazineIssue(
    id: 1,
    title: 'September 2025',
    coverUrl:
        'https://images.unsplash.com/photo-1600607687920-4e2a09cf159d?auto=format&fit=crop&w=900&q=80',
    date: DateTime(2025, 9, 1),
    description:
        'Industry insights, expert opinions, market trends, and technology updates.',
    fileSize: '68 MB',
    readUrl:
        'https://www.woodandpanel.com/flipbooks/2026/july-aug26-new/index.html',
    pdfUrl:
        'https://www.woodandpanel.com/flipbooks/2026/july-aug26-new/offline/download.pdf',
  ),
  MagazineIssue(
    id: 2,
    title: 'August 2025',
    coverUrl:
        'https://images.unsplash.com/photo-1600210492493-0946911123ea?auto=format&fit=crop&w=900&q=80',
    date: DateTime(2025, 8, 1),
    description: 'Panel manufacturing, exports, events, and machinery updates.',
    fileSize: '62 MB',
    readUrl: 'https://www.woodandpanel.com/archive/archive-2025/',
    pdfUrl: 'https://www.woodandpanel.com/archive/archive-2025/',
  ),
];

final _events = <AppEvent>[
  AppEvent(
    title: 'IndiaWood 2025',
    date: '27 Feb - 02 Mar 2025',
    location: 'BIEC, Bengaluru',
    imageUrl:
        'https://images.unsplash.com/photo-1540575467063-178a50c2df87?auto=format&fit=crop&w=1200&q=80',
  ),
  AppEvent(
    title: 'DelhiWood 2025',
    date: '12 - 15 Apr 2025',
    location: 'IEML, Greater Noida',
    imageUrl:
        'https://images.unsplash.com/photo-1505373877841-8d25f7d46678?auto=format&fit=crop&w=1200&q=80',
  ),
];
