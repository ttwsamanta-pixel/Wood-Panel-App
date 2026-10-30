import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/edition/edition.dart';

final bookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  return BookmarkRepository(edition: ref.watch(editionProvider).name);
});

class BookmarkRepository {
  BookmarkRepository({this.edition = 'europe'});
  final String edition;
  String get _articleKey => 'bookmarked_article_ids_v2:$edition';

  Future<Set<int>> articleIds() async {
    final prefs = await SharedPreferences.getInstance();
    if (edition == 'europe' && !prefs.containsKey(_articleKey)) {
      await prefs.setStringList(
          _articleKey, prefs.getStringList('bookmarked_article_ids') ?? []);
    }
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
