import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wood_panel_app/core/edition/edition.dart';
void main() {
  test('iOS selects Apple link independently, without Android fallback', () {
    const apple = 'https://apps.apple.com/us/app/wood-panel/id123456789';
    const eu = EditionConfig(edition: Edition.europe, appStoreUrl: 'https://play.google.com/store/apps/details?id=com.example.app');
    const us = EditionConfig(edition: Edition.usa, iosStoreUrl: apple);
    expect(selectAppStoreUrl(eu, us, platform: TargetPlatform.iOS), apple);
    expect(selectAppStoreUrl(eu, us, platform: TargetPlatform.android), eu.appStoreUrl);
    expect(selectAppStoreUrl(eu, const EditionConfig(edition: Edition.usa), platform: TargetPlatform.iOS), '');
    expect(selectAppStoreUrl(const EditionConfig(edition: Edition.europe, iosStoreUrl: apple), us, platform: TargetPlatform.iOS), apple);
    expect(validIosStoreUrl('https://apps.apple.com.evil.test/app/id123'), '');
    expect(validIosStoreUrl('https://apps.apple.com/us/app/no-id'), '');
    expect(validIosStoreUrl('https://apps.apple.com/app/id123?pt=1'), 'https://apps.apple.com/app/id123?pt=1');
  });
  const url = 'https://play.google.com/store/apps/details?id=com.example.app';
  test('Store link works from either site with consistent precedence', () {
    const eu = EditionConfig(edition: Edition.europe);
    const us = EditionConfig(edition: Edition.usa);
    const euLink = EditionConfig(edition: Edition.europe, appStoreUrl: url);
    const usLink = EditionConfig(edition: Edition.usa, appStoreUrl: url);
    expect(selectAppStoreUrl(eu, usLink), url);
    expect(selectAppStoreUrl(euLink, us), url);
    expect(selectAppStoreUrl(eu, us), '');
    expect(selectAppStoreUrl(euLink, const EditionConfig(edition: Edition.usa, appStoreUrl: '$url.other')), url);
  });
  test('Reject non-store links and missing package IDs', () {
    for (final value in [null, 123, 'javascript:alert(1)', 'https://example.com/', 'https://play.google.com/store/apps/details', 'https://play.google.com.evil.test/store/apps/details?id=x']) {
      expect(validAppStoreUrl(value), '');
    }
    expect(validAppStoreUrl(url), url);
  });
}
