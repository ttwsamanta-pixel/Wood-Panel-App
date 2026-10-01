import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart' as xml;

import '../models/content_models.dart';

final youtubeVideoRepositoryProvider = Provider<YouTubeVideoRepository>((ref) {
  return YouTubeVideoRepository();
});

class YouTubeVideoRepository {
  YouTubeVideoRepository({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 15),
              ),
            );

  static const channelId = 'UChylAsyNbYR6yvGmPz59iCA';
  static const channelUrl = 'https://www.youtube.com/woodandpanel';
  static const _videosUrl = '$channelUrl/videos';
  static const _feedUrl =
      'https://www.youtube.com/feeds/videos.xml?channel_id=$channelId';
  static const _cacheKey = 'youtube_videos_cache_v1';
  static const _mediaNamespace = 'http://search.yahoo.com/mrss/';
  static const _youtubeNamespace = 'http://www.youtube.com/xml/schemas/2015';

  final Dio _dio;

  Future<List<YouTubeVideo>> latestVideos({int limit = 50}) async {
    final cached = await _cachedVideos(limit: limit);
    if (cached.isNotEmpty) {
      unawaited(_refreshCache(limit: limit));
      return cached;
    }

    final videos = await _fetchLatestVideos(limit: limit);
    await _saveVideos(videos);
    return videos;
  }

  Future<List<YouTubeVideo>> _fetchLatestVideos({required int limit}) async {
    final rssVideos = await _tryLatestVideosFromRss();
    final videosById = {
      for (final video in rssVideos) video.id: video,
    };
    final orderedIds = <String>[];

    for (final video in rssVideos) {
      orderedIds.add(video.id);
    }

    try {
      final pageVideos = await _latestVideosFromChannelPage(limit: limit);
      for (final video in pageVideos) {
        videosById.putIfAbsent(video.id, () => video);
        if (!orderedIds.contains(video.id)) {
          orderedIds.add(video.id);
        }
      }
    } catch (_) {
      // RSS is the stable fallback if YouTube changes the public page shape.
    }

    final videos = orderedIds
        .take(limit)
        .map((id) => videosById[id])
        .whereType<YouTubeVideo>()
        .toList();
    if (videos.isNotEmpty) {
      return videos;
    }
    return _fallbackVideos.take(limit).toList();
  }

  Future<void> _refreshCache({required int limit}) async {
    try {
      final videos = await _fetchLatestVideos(limit: limit);
      if (videos.isNotEmpty) {
        await _saveVideos(videos);
      }
    } on Object {
      // Keep the existing cache if YouTube is slow or unavailable.
    }
  }

  Future<List<YouTubeVideo>> _cachedVideos({required int limit}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached == null) {
        return const <YouTubeVideo>[];
      }
      final decoded = jsonDecode(cached) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(YouTubeVideo.fromJson)
          .take(limit)
          .toList(growable: false);
    } on Object {
      return const <YouTubeVideo>[];
    }
  }

  Future<void> _saveVideos(List<YouTubeVideo> videos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode([for (final video in videos) video.toJson()]),
    );
  }

  Future<List<YouTubeVideo>> _tryLatestVideosFromRss() async {
    try {
      return await _latestVideosFromRss();
    } on Object {
      return const <YouTubeVideo>[];
    }
  }

  Future<List<YouTubeVideo>> _latestVideosFromRss() async {
    final response = await _dio.get<String>(
      _feedUrl,
      options: Options(responseType: ResponseType.plain),
    );
    final document = xml.XmlDocument.parse(response.data ?? '');
    return document.findAllElements('entry').map(_videoFromEntry).toList();
  }

  Future<List<YouTubeVideo>> _latestVideosFromChannelPage({
    required int limit,
  }) async {
    final response = await _dio.get<String>(
      _videosUrl,
      options: Options(
        responseType: ResponseType.plain,
        headers: const {'User-Agent': 'Mozilla/5.0'},
      ),
    );
    final html = response.data ?? '';
    final ids = RegExp(r'"videoId":"([^"]+)"')
        .allMatches(html)
        .map((match) => match.group(1) ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .take(limit);

    return [
      for (final id in ids)
        YouTubeVideo(
          id: id,
          title: _videoTitleFromHtml(html, id),
          description: '',
          thumbnailUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
          url: 'https://www.youtube.com/watch?v=$id',
          publishedAt: DateTime.now(),
          views: 0,
        ),
    ];
  }

  YouTubeVideo _videoFromEntry(xml.XmlElement entry) {
    final id = _text(entry, 'videoId', namespaceUri: _youtubeNamespace);
    final mediaGroup =
        _first(entry.findElements('group', namespaceUri: _mediaNamespace));
    final thumbnail = _first<xml.XmlElement>(
      mediaGroup?.findElements('thumbnail', namespaceUri: _mediaNamespace) ??
          const Iterable<xml.XmlElement>.empty(),
    );
    final statistics = _first<xml.XmlElement>(
      mediaGroup?.findAllElements('statistics',
              namespaceUri: _mediaNamespace) ??
          const Iterable<xml.XmlElement>.empty(),
    );
    final link = _first(entry.findElements('link'))?.getAttribute('href') ??
        'https://www.youtube.com/watch?v=$id';

    return YouTubeVideo(
      id: id,
      title: _text(entry, 'title'),
      description:
          _text(mediaGroup, 'description', namespaceUri: _mediaNamespace),
      thumbnailUrl: thumbnail?.getAttribute('url') ??
          'https://i.ytimg.com/vi/$id/hqdefault.jpg',
      url: link,
      publishedAt:
          DateTime.tryParse(_text(entry, 'published')) ?? DateTime.now(),
      views: int.tryParse(statistics?.getAttribute('views') ?? '') ?? 0,
    );
  }

  String _text(xml.XmlElement? element, String name, {String? namespaceUri}) {
    if (element == null) return '';
    return _first(element.findElements(name, namespaceUri: namespaceUri))
            ?.innerText
            .trim() ??
        '';
  }

  String _videoTitleFromHtml(String html, String videoId) {
    final escapedId = RegExp.escape(videoId);
    final match = RegExp(
      '"videoId":"$escapedId".{0,5000}?"title":\\{"content":"([^"]+)"',
      dotAll: true,
    ).firstMatch(html);
    final title = match?.group(1);
    if (title == null || title.trim().isEmpty) {
      return 'Wood & Panel Video';
    }
    return _decodeEscapedText(title);
  }

  String _decodeEscapedText(String value) {
    return value
        .replaceAll(r'\u0026', '&')
        .replaceAll(r'\"', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#39;', "'")
        .replaceAll('&quot;', '"');
  }

  T? _first<T>(Iterable<T> items) {
    final iterator = items.iterator;
    if (iterator.moveNext()) {
      return iterator.current;
    }
    return null;
  }

  List<YouTubeVideo> get _fallbackVideos => [
        _fallbackVideo(
          id: 'nurFQ-MPxCc',
          title:
              'Inside Urban Ladder’s Smart Manufacturing: The Power of imos Software',
          publishedAt: DateTime(2026, 8, 4),
        ),
        _fallbackVideo(
          id: '2RoIW7o2YAU',
          title:
              'Exclusive: imos at Xylexpo 2026 | AI Software Innovations & European Market Strategy',
          publishedAt: DateTime(2026, 8, 4),
        ),
        _fallbackVideo(
          id: '49niJoMTMJg',
          title:
              "Beyond Woodworking: Luciano Deidda on Freud Tools' New Aluminum Cutting Saw Blades",
          publishedAt: DateTime(2026, 8, 4),
        ),
        _fallbackVideo(
          id: 'SFDOO0RA498',
          title:
              'Next-Gen CNC Tooling: Eugenio Laghi on Sistemi Klein’s Hydro Block & Chrome Blades',
          publishedAt: DateTime(2026, 8, 4),
        ),
        _fallbackVideo(
          id: 'icRotupaD6g',
          title: 'Biesse Unveils Hybrid Woodworking Technology at Xylexpo 2026',
          publishedAt: DateTime(2026, 8, 4),
        ),
        _fallbackVideo(
          id: 'OmNANoNz_AQ',
          title:
              'Robopac Reinvents Furniture Packaging at Xylexpo 2026 | Raphaël Prati Interview',
          publishedAt: DateTime(2026, 8, 4),
        ),
      ];

  YouTubeVideo _fallbackVideo({
    required String id,
    required String title,
    required DateTime publishedAt,
  }) {
    return YouTubeVideo(
      id: id,
      title: title,
      description: '',
      thumbnailUrl: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
      url: 'https://www.youtube.com/watch?v=$id',
      publishedAt: publishedAt,
      views: 0,
    );
  }
}
