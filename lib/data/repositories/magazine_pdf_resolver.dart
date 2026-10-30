import 'package:dio/dio.dart';
import '../../core/edition/edition.dart';

/// Check the publisher's exported PDF before offering a download.
class MagazinePdfResolver {
  static final _verified = <String, Future<String>>{};
  static Future<String> resolve(String reader, {Dio? client}) =>
      _verified.putIfAbsent(reader, () => _check(reader, client));

  static Future<String> _check(String reader, Dio? client) async {
    final uri = Uri.tryParse(reader);
    if (uri == null ||
        uri.scheme != 'https' ||
        Edition.forHost(uri.host) == null ||
        !(uri.path.startsWith('/flipbooks/') ||
            uri.path.startsWith('/flipbook/'))) {
      return '';
    }
    final base = uri.path.endsWith('/') ? uri : uri.resolve('./');
    final pdf = base.resolve('offline/download.pdf');
    final dio = client ??
        Dio(BaseOptions(
            headers: const {'User-Agent': 'Mozilla/5.0'},
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 8)));
    try {
      final response = await dio.head(pdf.toString());
      return response.statusCode == 200 &&
              (response.headers.value('content-type') ?? '')
                  .toLowerCase()
                  .contains('application/pdf')
          ? pdf.toString()
          : '';
    } catch (_) {
      _verified.remove(
          reader); // Allow a later retry after a temporary network failure.
      return '';
    } finally {
      if (client == null) dio.close();
    }
  }
}
