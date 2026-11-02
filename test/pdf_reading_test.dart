import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wood_panel_app/data/repositories/download_repository.dart';
import 'package:wood_panel_app/data/repositories/pdf_reading_repository.dart';

void main() {
  DownloadedFile file({String edition = 'europe', String path = '/old.pdf', String url = 'https://example.com/issue.pdf'}) =>
      DownloadedFile(title: 'Issue', url: url, path: path, size: 10,
        downloadedAt: DateTime(2026), edition: edition);

  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('Reading state survives reload and re-download, isolated by edition and issue', () async {
    final repo = PdfReadingRepository(await SharedPreferences.getInstance());
    await repo.save(file(), const PdfReadingState(page: 12, bookmarks: [8, 2, 8]));
    final reopened = PdfReadingRepository(await SharedPreferences.getInstance());
    expect(reopened.read(file(path: '/new.pdf')).page, 12);
    expect(reopened.read(file()).bookmarks, [2, 8]);
    expect(reopened.read(file(edition: 'usa')).page, 0);
    expect(reopened.read(file(url: 'https://example.com/other.pdf')).bookmarks, isEmpty);
    await repo.save(file(), const PdfReadingState(page: 3, bookmarks: [8]));
    expect(reopened.read(file()).bookmarks, [8]);
  });
  test('Corrupt state starts at cover and shorter replacement PDFs clamp progress', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = PdfReadingRepository(prefs);
    await prefs.setString(PdfReadingRepository.keyFor(file()), 'broken');
    expect(repo.read(file()).page, 0);
    await prefs.setString(PdfReadingRepository.keyFor(file()), '{"page":-4,"bookmarks":[-2,3,"bad",3,90]}');
    final bounded = repo.read(file()).bounded(10);
    expect(bounded.page, 0);
    expect(bounded.bookmarks, [3]);
    expect(const PdfReadingState(page: 90).bounded(10).page, 9);
  });
}
