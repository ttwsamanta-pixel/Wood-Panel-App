import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final bookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  return BookmarkRepository();
});

class BookmarkRepository {
  static const _articleKey = 'bookmarked_article_ids';

  Future<Set<int>> articleIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs
        .getStringList(_articleKey)
        ?.map(int.tryParse)
        .whereType<int>()
        .toSet() ??
        <int>{};
  }

  Future<bool> isBookmarked(int articleId) async {
    final ids = await articleIds();
    return ids.contains(articleId);
  }

  Future<void> setArticleBookmark(int articleId, bool bookmarked) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = await articleIds();
    if (bookmarked) {
      ids.add(articleId);
    } else {
      ids.remove(articleId);
    }
    await prefs.setStringList(
      _articleKey,
      ids.map((id) => id.toString()).toList()..sort(),
    );
  }
}
