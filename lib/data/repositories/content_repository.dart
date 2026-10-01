import '../models/content_models.dart';

abstract class ContentRepository {
  Future<List<Article>> latestArticles({int page = 1, int perPage = 12});
  Future<List<Article>> articlesByCategory({
    required int categoryId,
    String? categoryName,
    int page = 1,
    int perPage = 12,
  });
  Future<List<Article>> latestInterviews({int page = 1, int perPage = 12});
  Future<List<Article>> searchArticles(String query,
      {int page = 1, int perPage = 12});
  Future<Article> articleById(int id);
  Future<List<MagazineIssue>> magazines();
  Future<List<AppEvent>> events();
}
