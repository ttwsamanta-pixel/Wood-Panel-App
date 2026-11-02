import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wood_panel_app/data/repositories/download_repository.dart';

void main() {
  test('Delete removes only selected PDF and permits downloading it again',
      () async {
    final dir = await Directory.systemTemp.createTemp('wp-download-delete-');
    try {
      final items = <DownloadedFile>[];
      for (final edition in ['europe', 'usa']) {
        final file =
            await File('${dir.path}/$edition.pdf').writeAsString('%PDF-test');
        items.add(DownloadedFile(
            title: 'Issue',
            url: 'https://example.com/issue.pdf',
            path: file.path,
            size: 9,
            downloadedAt: DateTime(2026),
            edition: edition));
      }
      SharedPreferences.setMockInitialValues({
        'app_downloads_v1': jsonEncode(items.map((e) => e.toJson()).toList())
      });
      final repo = DownloadRepository(Dio());
      await repo.deletePdf(items.first);
      expect(File(items.first.path).existsSync(), false);
      expect(File(items.last.path).existsSync(), true);
      expect((await repo.files()).single.edition, 'usa');
      expect(await repo.fileForUrl(items.first.url), isNull);
      await repo.deletePdf(items.first);
      expect((await repo.files()).length, 1);
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
