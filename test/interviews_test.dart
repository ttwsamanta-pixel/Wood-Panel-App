import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wood_panel_app/core/edition/edition.dart';
import 'package:wood_panel_app/core/network/api_client.dart';
import 'package:wood_panel_app/data/repositories/wordpress_content_repository.dart';

void main() {
  for (final edition in Edition.values) {
    test(
        '${edition.name} managed interviews combine posts and legacy archive on page 2',
        () async {
      final dio = Dio();
      addTearDown(dio.close);
      var requestedPage = 0;
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        dynamic data;
        if (options.path.endsWith('/categories')) {
          data = [
            {'id': 41}
          ];
        } else if (options.path.endsWith('/posts')) {
          requestedPage = options.queryParameters['page'];
          data = [
            {
              'id': 8,
              'title': {'rendered': 'Post interview'},
              'excerpt': {'rendered': ''},
              'categories': [],
              'link': '${edition.site}/news/example'
            }
          ];
        } else if (options.path == '/interviews/page/2/') {
          data = edition == Edition.usa
              ? '<li class="wpusa-interview-item"><h3 class="name"><a href="${edition.site}/interview/?interview=person">Legacy interview</a></h3><img data-src="${edition.site}/person.jpg"><p>Summary</p></li>'
              : '<div class="cat-post interview-post"><a href="${edition.site}/interview/person"><img data-breeze="${edition.site}/person.jpg"></a><h3>Legacy interview</h3><p>Summary</p></div>';
        } else {
          throw StateError('Unexpected request: ${options.path}');
        }
        handler.resolve(
            Response(requestOptions: options, data: data, statusCode: 200));
      }));
      final repository = WordPressContentRepository(
          ApiClient(dio: dio, baseUrl: edition.site),
          config: EditionConfig(edition: edition, managed: true));
      final items = await repository.latestInterviews(page: 2);
      expect(requestedPage, 2);
      expect(items.map((item) => item.title),
          ['Post interview', 'Legacy interview']);
      expect(items.last.imageUrl, '${edition.site}/person.jpg');
      expect(items.last.id, lessThan(0));
    });
  }
}
