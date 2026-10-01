import '../models/content_models.dart';
import 'content_repository.dart';

class HybridContentRepository implements ContentRepository {
  const HybridContentRepository({
    required this.remote,
    required this.fallback,
  });

  final ContentRepository remote;
  final ContentRepository fallback;

  @override
  Future<List<Article>> latestArticles({int page = 1, int perPage = 12}) async {
    try {
      final articles =
          await remote.latestArticles(page: page, perPage: perPage);
      return articles.isEmpty
          ? await fallback.latestArticles(page: page, perPage: perPage)
          : articles;
    } catch (_) {
      return fallback.latestArticles(page: page, perPage: perPage);
    }
  }

  @override
  Future<List<Article>> articlesByCategory({
    required int categoryId,
    String? categoryName,
    int page = 1,
    int perPage = 12,
  }) async {
    try {
      final articles = await remote.articlesByCategory(
        categoryId: categoryId,
        categoryName: categoryName,
        page: page,
        perPage: perPage,
      );
      return articles.isEmpty
          ? await fallback.articlesByCategory(
              categoryId: categoryId,
              categoryName: categoryName,
              page: page,
              perPage: perPage,
            )
          : articles;
    } catch (_) {
      return fallback.articlesByCategory(
        categoryId: categoryId,
        categoryName: categoryName,
        page: page,
        perPage: perPage,
      );
    }
  }

  @override
  Future<List<Article>> latestInterviews(
      {int page = 1, int perPage = 12}) async {
    try {
      final articles =
          await remote.latestInterviews(page: page, perPage: perPage);
      return articles.isEmpty
          ? await fallback.latestInterviews(page: page, perPage: perPage)
          : articles;
    } catch (_) {
      return fallback.latestInterviews(page: page, perPage: perPage);
    }
  }

  @override
  Future<Article> articleById(int id) async {
    try {
      return await remote.articleById(id);
    } catch (_) {
      return fallback.articleById(id);
    }
  }

  @override
  Future<List<Article>> searchArticles(String query,
      {int page = 1, int perPage = 12}) async {
    try {
      final articles =
          await remote.searchArticles(query, page: page, perPage: perPage);
      return articles.isEmpty
          ? await fallback.searchArticles(query, page: page, perPage: perPage)
          : articles;
    } catch (_) {
      return fallback.searchArticles(query, page: page, perPage: perPage);
    }
  }

  @override
  Future<List<MagazineIssue>> magazines() async {
    try {
      final issues = await remote.magazines();
      return issues.isEmpty ? await fallback.magazines() : issues;
    } catch (_) {
      return fallback.magazines();
    }
  }

  @override
  Future<List<AppEvent>> events() async {
    try {
      final appEvents = await remote.events();
      return appEvents.isEmpty ? await fallback.events() : appEvents;
    } catch (_) {
      return fallback.events();
    }
  }
}
