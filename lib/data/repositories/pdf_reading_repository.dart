import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'download_repository.dart';

class PdfReadingState {
  const PdfReadingState({this.page = 0, this.bookmarks = const []});
  final int page;
  final List<int> bookmarks;

  PdfReadingState bounded(int pages) => PdfReadingState(
      page: pages > 0 ? page.clamp(0, pages - 1) : 0,
      bookmarks: bookmarks.where((p) => p >= 0 && p < pages).toList());
}

/// URL identity survives re-downloads; edition prevents cross-edition mixing.
class PdfReadingRepository {
  PdfReadingRepository(this.preferences);
  final SharedPreferences preferences;
  static String keyFor(DownloadedFile file) => 'pdf_reading_v1:${jsonEncode([
            file.edition,
            file.url.isEmpty ? file.path : file.url
          ])}';

  PdfReadingState read(DownloadedFile file) {
    try {
      final raw = preferences.getString(keyFor(file));
      if (raw == null) return const PdfReadingState();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final page = json['page'];
      final marks = json['bookmarks'];
      return PdfReadingState(
          page: page is int && page >= 0 ? page : 0,
          bookmarks: marks is List
              ? (marks.whereType<int>().where((p) => p >= 0).toSet().toList()
                ..sort())
              : const []);
    } catch (_) {
      return const PdfReadingState();
    }
  }

  Future<void> save(DownloadedFile file, PdfReadingState state) async {
    final saved = await preferences.setString(
        keyFor(file),
        jsonEncode({
          'page': state.page,
          'bookmarks': state.bookmarks.toSet().toList()..sort(),
        }));
    if (!saved) throw StateError('Reading progress could not be saved');
  }
}
