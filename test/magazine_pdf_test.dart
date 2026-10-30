import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wood_panel_app/data/repositories/magazine_pdf_resolver.dart';

class HeadAdapter implements HttpClientAdapter {
  HeadAdapter(this.mime);
  final String mime;
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancel) async {
    request = options;
    return ResponseBody.fromString('', 200, headers: {
      'content-type': [mime]
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('USA trailing directory and Europe index resolve verified PDFs',
      () async {
    for (final reader in [
      'https://www.woodandpanel.us/flipbook/2026/Jan_Feb26/',
      'https://www.woodandpanel.com/flipbooks/2026/sep-oct26/index.html'
    ]) {
      final adapter = HeadAdapter('application/pdf');
      final dio = Dio()..httpClientAdapter = adapter;
      final result = await MagazinePdfResolver.resolve(reader, client: dio);
      expect(result.endsWith('/offline/download.pdf'), isTrue);
      expect(Uri.parse(result).host, Uri.parse(reader).host);
      expect(adapter.request!.method, 'HEAD');
    }
  });
  test('HTML errors and non-publisher links do not enable PDF', () async {
    final adapter = HeadAdapter('text/html');
    final dio = Dio()..httpClientAdapter = adapter;
    expect(
        await MagazinePdfResolver.resolve(
            'https://www.woodandpanel.us/flipbook/missing/index.html',
            client: dio),
        '');
    adapter.request = null;
    expect(
        await MagazinePdfResolver.resolve(
            'https://example.com/flipbook/index.html',
            client: dio),
        '');
    expect(adapter.request, isNull);
  });
}
