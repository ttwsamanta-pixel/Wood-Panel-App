import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wood_panel_app/core/edition/ad_analytics.dart';
import 'package:wood_panel_app/core/edition/edition.dart';

void main() {
  test('only sustained visible exposures count, with a new identity on return',
      () {
    final exposure = AdExposure();
    final now = DateTime.utc(2026, 10, 27);
    expect(exposure.sample(false, now), isFalse); // preloaded/failed/offscreen
    expect(exposure.sample(true, now), isFalse);
    expect(exposure.sample(true, now.add(const Duration(milliseconds: 900))),
        isFalse);
    expect(exposure.sample(false, now.add(const Duration(milliseconds: 950))),
        isFalse);
    expect(exposure.sample(true, now.add(const Duration(seconds: 1))), isFalse);
    final identity = exposure.viewId;
    expect(exposure.sample(true, now.add(const Duration(seconds: 2))), isTrue);
    expect(exposure.sample(true, now.add(const Duration(seconds: 3))), isFalse);
    exposure.sample(
        false, now.add(const Duration(seconds: 4))); // background or hidden
    expect(exposure.viewId, isNot(identity));
    expect(exposure.sample(true, now.add(const Duration(seconds: 5))), isFalse);
    expect(exposure.sample(true, now.add(const Duration(seconds: 6))), isTrue);
  });

  test('event retry keeps identity and refuses the wrong edition', () async {
    final requests = <RequestOptions>[];
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      if (requests.length == 1) {
        handler.reject(DioException(
            requestOptions: options, type: DioExceptionType.connectionError));
      } else {
        handler.resolve(Response(requestOptions: options, statusCode: 200));
      }
    }));
    final analytics = AdAnalytics(dio: dio);
    const banner = {
      'id': '7',
      'placement': 'footer_ads',
      'tracking_token': 'test-token',
      'tracking_url':
          'https://www.woodandpanel.us/wp-json/wood-panel-app/v1/ad-event'
    };
    final id = newAdViewId();
    await analytics.record(Edition.europe, banner, id, 'impression');
    expect(requests, isEmpty);
    await analytics.record(
        Edition.usa,
        {...banner, 'tracking_url': 'https://untrusted.example/ad-event'},
        id,
        'impression');
    expect(requests, isEmpty);
    await analytics.record(Edition.usa, banner, id, 'impression');
    expect(requests.length, 2);
    expect(requests.first.data['view_id'], requests.last.data['view_id']);
    expect(
        requests.first.data.keys,
        unorderedEquals(
            ['banner_id', 'placement', 'token', 'view_id', 'type']));
    analytics.dispose();
  });

  test('tracking metadata survives configuration for all placements', () {
    const banner = {
      'id': '42',
      'image_url': 'https://example.com/banner.png',
      'tracking_token': 'signed',
      'tracking_url':
          'https://www.woodandpanel.us/wp-json/wood-panel-app/v1/ad-event'
    };
    final config = EditionConfig.fromJson(Edition.usa, {
      'schema_version': 1,
      'edition': 'usa',
      'banners': [banner],
      'inline_ads': [banner],
      'footer_ads': [banner]
    });
    for (final ads in [config.banners, config.inlineAds, config.footerAds]) {
      expect(ads.single['id'], '42');
      expect(ads.single['tracking_token'], 'signed');
    }
    expect(config.banners.single['placement'], 'banners');
    expect(config.inlineAds.single['placement'], 'inline_ads');
    expect(config.footerAds.single['placement'], 'footer_ads');
  });
}
