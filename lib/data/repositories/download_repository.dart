import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadedFile {
  const DownloadedFile({
    required this.title,
    required this.url,
    required this.path,
    required this.size,
    required this.downloadedAt,
    this.coverUrl = '',
  });

  final String title;
  final String url;
  final String path;
  final int size;
  final DateTime downloadedAt;
  final String coverUrl;

  factory DownloadedFile.fromJson(Map<String, dynamic> json) {
    return DownloadedFile(
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      path: json['path'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      downloadedAt: DateTime.tryParse(json['downloadedAt'] as String? ?? '') ??
          DateTime.now(),
      coverUrl: json['coverUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'url': url,
        'path': path,
        'size': size,
        'downloadedAt': downloadedAt.toIso8601String(),
        'coverUrl': coverUrl,
      };
}

class DownloadRepository {
  DownloadRepository(this._dio);

  static const _key = 'app_downloads_v1';

  final Dio _dio;

  Future<List<DownloadedFile>> files() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) {
      return const [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(DownloadedFile.fromJson)
        .where((file) => File(file.path).existsSync())
        .toList(growable: false);
  }

  Future<DownloadedFile?> fileForUrl(String url) async {
    for (final file in await files()) {
      if (file.url == url) {
        return file;
      }
    }
    return null;
  }

  Future<DownloadedFile> downloadPdf({
    required String title,
    required String url,
    String coverUrl = '',
  }) async {
    final directory = await _downloadDirectory();
    final fileName = '${_safeFileName(title)}.pdf';
    final path = '${directory.path}${Platform.pathSeparator}$fileName';
    await _dio.download(url, path);
    final file = File(path);
    final item = DownloadedFile(
      title: title,
      url: url,
      path: path,
      size: await file.length(),
      downloadedAt: DateTime.now(),
      coverUrl: coverUrl,
    );
    final existing = await files();
    final next = [
      item,
      for (final file in existing)
        if (file.url != url) file,
    ];
    await _save(next);
    return item;
  }

  Future<void> _save(List<DownloadedFile> files) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(files.map((file) => file.toJson()).toList()),
    );
  }

  Future<Directory> _downloadDirectory() async {
    final baseDirectory = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${baseDirectory.path}${Platform.pathSeparator}downloads',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String _safeFileName(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return cleaned.isEmpty ? 'wood_panel_download' : cleaned;
  }
}
