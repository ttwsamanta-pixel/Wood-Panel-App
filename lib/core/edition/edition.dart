import 'package:flutter/foundation.dart';
import 'social_defaults.dart';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/news_category.dart';
import 'banner_preloader.dart';

enum Edition {
  europe('Europe', 'https://www.woodandpanel.com'),
  usa('USA', 'https://www.woodandpanel.us');

  const Edition(this.label, this.site);
  final String label;
  final String site;
  String get topic => 'wood_panel_$name';

  static Edition? forHost(String host) => switch (host.toLowerCase()) {
        'woodandpanel.com' || 'www.woodandpanel.com' => europe,
        'woodandpanel.us' || 'www.woodandpanel.us' => usa,
        _ => null,
      };
}

// Deliberately runtime-only: each new ProviderScope starts in Europe.
final editionProvider = StateProvider<Edition>((ref) => Edition.europe);
final editionConfigProvider =
    FutureProvider.family<EditionConfig, Edition>((ref, edition) async {
  final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      responseType: ResponseType.plain));
  ref.onDispose(() => dio.close(force: true));
  final prefs = await SharedPreferences.getInstance();
  final key = 'edition_config_v1:${edition.name}';
  final saved = prefs.getString(key);
  if (saved != null) {
    try {
      EditionConfig.fromJson(edition, jsonDecode(saved) as Map<String, dynamic>)
          .preloadBanners();
    } catch (_) {/* Ignore invalid cached configuration. */}
  }
  try {
    final response = await dio
        .get<String>('${edition.site}/wp-json/wood-panel-app/v1/config');
    final json =
        jsonDecode((response.data ?? '').replaceFirst('\uFEFF', '').trim())
            as Map<String, dynamic>;
    final result = EditionConfig.fromJson(edition, json);
    result.preloadBanners();
    await prefs.setString(key, jsonEncode(json));
    await prefs.setInt('$key:time', DateTime.now().millisecondsSinceEpoch);
    return result;
  } catch (_) {
    if (saved != null) {
      try {
        return EditionConfig.fromJson(
            edition, jsonDecode(saved) as Map<String, dynamic>);
      } catch (_) {/* Use only this edition's fallback. */}
    }
    // A site can serve news before its App Manager plugin is installed.
    var categories =
        edition == Edition.europe ? NewsCategory.all : <NewsCategory>[];
    if (edition == Edition.europe) {
      return EditionConfig(
          edition: edition, categories: categories, homeCategories: categories);
    }
    try {
      final response = await dio.get<String>(
          '${edition.site}/wp-json/wp/v2/categories',
          queryParameters: {'per_page': 100, 'hide_empty': true});
      final values =
          jsonDecode((response.data ?? '').replaceFirst('\uFEFF', '').trim())
              as List;
      if (edition == Edition.usa) {
        categories = values
            .map((v) => NewsCategory(
                id: (v['id'] as num).toInt(), name: v['name'] as String))
            .toList();
      }
    } catch (_) {/* Leave unavailable categories empty. */}
    return EditionConfig(
        edition: edition, categories: categories, homeCategories: categories);
  }
});

final activeConfigProvider = Provider<EditionConfig>((ref) {
  final edition = ref.watch(editionProvider);
  return ref.watch(editionConfigProvider(edition)).valueOrNull ??
      EditionConfig(edition: edition);
});

const defaultContactDetails = <String, String>{
  'usa_address': '244 5th Avenue, Suite 2468,\nNew York, N.Y. 10001',
  'usa_phone': '+1 917 677 7753',
  'usa_whatsapp': '+49 152 22067848',
  'india_address': 'S-303 Ideal Plaza, 11/1\nSarat Bose Road, Kolkata 700020',
  'india_phone': '+91 33 4603 4660',
  'india_mobile': '+91 9836877999',
  'email': 'editor@woodandpanel.com',
  'email_secondary': 'woodandpanel@gmail.com',
  'team_name': 'Ms. Chitralekha Banerjee',
  'team_role': 'Editor, Manager - Public Relations',
  'team_email': 'pr@woodandpanel.com',
  'team_phone': '+91 33 4603 4660'
};

class EditionConfig {
  const EditionConfig(
      {required this.edition,
      this.managed = false,
      this.logoUrl = '',
      this.appStoreUrl = '',
      this.iosStoreUrl = '',
      this.preloaderUrl = '',
      this.preloaderColor = const Color(0xFF211F21),
      Color? primary,
      Color? secondary,
      this.categories = const [],
      this.homeCategories = const [],
      this.banners = const [],
      this.inlineAds = const [],
      this.footerAds = const [],
      this.sections = const [
        'banners',
        'categories',
        'latest',
        'trending',
        'videos',
        'magazines',
        'events',
        'newsletter'
      ],
      this.interviewCategories = const [],
      this.featuredIds = const [],
      this.newsletter = true,
      this.contact = true,
      this.aboutPageId = 0,
      this.contactPageId = 0,
      this.socialLinks = defaultSocialLinks,
      this.contactDetails = defaultContactDetails,
      this.defaultWallpapers = true,
      this.wallpapers = const []})
      : primary = primary ??
            (edition == Edition.usa
                ? const Color(0xFFA41E22)
                : const Color(0xFFA54F17)),
        secondary = secondary ??
            (edition == Edition.usa
                ? const Color(0xFF223268)
                : const Color(0xFF034F29));

  final Edition edition;
  final bool managed;
  final String logoUrl;
  final String appStoreUrl;
  final String iosStoreUrl;
  final String preloaderUrl;
  final Color preloaderColor;
  final Color primary, secondary;
  final List<NewsCategory> categories, homeCategories;
  final List<Map<String, String>> banners;
  final List<Map<String, String>> inlineAds, footerAds;
  final Map<String, String> socialLinks;
  final Map<String, String> contactDetails;
  final bool defaultWallpapers;
  final List<Map<String, String>> wallpapers;
  final List<String> sections;
  final List<int> interviewCategories, featuredIds;
  final bool newsletter, contact;
  final int aboutPageId, contactPageId;

  void preloadBanners() {
    // First visible placements first, then the rest of each rotation.
    BannerPreloader.warm([
      ...banners.take(1),
      ...footerAds.take(1),
      ...inlineAds.take(1),
      ...banners.skip(1),
      ...footerAds.skip(1),
      ...inlineAds.skip(1),
    ].map((banner) => banner['image_url'] ?? ''));
  }

  factory EditionConfig.fromJson(Edition edition, Map<String, dynamic> json) {
    if (json['schema_version'] != 1 || json['edition'] != edition.name) {
      throw const FormatException('Edition configuration mismatch');
    }
    final branding = json['branding'] as Map? ?? {};
    Color colour(String key, Color fallback) {
      if (branding['confirmed'] != true) return fallback;
      final text = branding[key]?.toString() ?? '';
      return RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(text)
          ? Color(int.parse('FF${text.substring(1)}', radix: 16))
          : fallback;
    }

    List<NewsCategory> categories(String key) => (json[key] as List? ?? [])
        .map((v) => NewsCategory(
            id: (v['id'] as num).toInt(), name: v['name'] as String))
        .toList();
    List<int> ids(String key) => (json[key] as List? ?? [])
        .whereType<num>()
        .map((v) => v.toInt())
        .where((v) => v > 0)
        .toList();
    List<Map<String, String>> ads(String key) => (json[key] as List? ?? [])
        .whereType<Map>()
        .map((v) => {
              'image_url': v['image_url']?.toString() ?? '',
              'link_url': v['link_url']?.toString() ?? '',
              'label': v['label']?.toString() ?? '',
              'size': v['size'] == '350x100' ? '350x100' : '350x50',
              'id': v['id']?.toString() ?? '',
              'placement': key,
              'tracking_token': v['tracking_token']?.toString() ?? '',
              'tracking_url': v['tracking_url']?.toString() ?? '',
            })
        .where((v) => Uri.tryParse(v['image_url']!)?.scheme == 'https')
        .toList();
    return EditionConfig(
        appStoreUrl: validAppStoreUrl(json['app_store_url']),
        iosStoreUrl: validIosStoreUrl(json['ios_store_url']),
        edition: edition,
        managed: true,
        inlineAds: ads('inline_ads'),
        footerAds: ads('footer_ads'),
        logoUrl: branding['logo_url'] as String? ?? '',
        preloaderUrl: branding['preloader_url'] as String? ?? '',
        preloaderColor: colour('preloader_color', const Color(0xFF211F21)),
        primary: colour('primary', EditionConfig(edition: edition).primary),
        secondary:
            colour('secondary', EditionConfig(edition: edition).secondary),
        categories: categories('explore_categories'),
        homeCategories: categories('home_categories'),
        sections:
            (json['home_sections'] as List? ?? []).whereType<String>().toList(),
        banners: ads('banners'),
        interviewCategories: ids('interview_categories'),
        featuredIds: ids('featured_ids'),
        contactDetails: {
          for (final key in defaultContactDetails.keys)
            key: json['contact_details'] is Map &&
                    (json['contact_details'] as Map)[key] is String
                ? (json['contact_details'] as Map)[key] as String
                : defaultContactDetails[key]!
        },
        socialLinks: {
          for (final key in defaultSocialLinks.keys)
            key: (json['social_links'] is Map &&
                    (json['social_links'] as Map).containsKey(key))
                ? (((json['social_links'] as Map)[key] is String &&
                        Uri.tryParse((json['social_links'] as Map)[key])
                                ?.scheme ==
                            'https')
                    ? (json['social_links'] as Map)[key] as String
                    : '')
                : defaultSocialLinks[key]!
        },
        defaultWallpapers: json['default_wallpapers_enabled'] != false,
        wallpapers: (json['wallpapers'] as List? ?? [])
            .map((v) => {
                  'id': v['id'].toString(),
                  'title': v['title'] as String? ?? '',
                  'category': v['category'] as String? ?? '',
                  'image_url': v['image_url'] as String? ?? '',
                })
            .where((v) => Uri.tryParse(v['image_url']!)?.scheme == 'https')
            .toList(),
        newsletter: (json['newsletter'] as Map?)?['enabled'] == true,
        contact: (json['contact'] as Map?)?['enabled'] == true,
        aboutPageId: (json['about_page_id'] as num?)?.toInt() ?? 0,
        contactPageId: (json['contact_page_id'] as num?)?.toInt() ?? 0);
  }
}

// This app has one store listing, shared by both regional editions.
String validAppStoreUrl(dynamic value) {
  if (value is! String) return '';
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
          uri.scheme == 'https' &&
          uri.host == 'play.google.com' &&
          uri.path == '/store/apps/details' &&
          (uri.queryParameters['id'] ?? '').isNotEmpty
      ? uri.toString()
      : '';
}

String validIosStoreUrl(dynamic value) {
  if (value is! String) return '';
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
          uri.scheme == 'https' &&
          uri.host == 'apps.apple.com' &&
          RegExp(r'/id[0-9]+/?$').hasMatch(uri.path)
      ? uri.toString()
      : '';
}

String selectAppStoreUrl(EditionConfig europe, EditionConfig usa,
    {TargetPlatform platform = TargetPlatform.android}) {
  if (platform == TargetPlatform.iOS) {
    final primary = validIosStoreUrl(europe.iosStoreUrl);
    return primary.isNotEmpty ? primary : validIosStoreUrl(usa.iosStoreUrl);
  }
  final primary = validAppStoreUrl(europe.appStoreUrl);
  return primary.isNotEmpty ? primary : validAppStoreUrl(usa.appStoreUrl);
}

final sharedAppStoreUrlProvider = FutureProvider<String>((ref) async {
  final configs = await Future.wait([
    ref.watch(editionConfigProvider(Edition.europe).future),
    ref.watch(editionConfigProvider(Edition.usa).future),
  ]);
  return selectAppStoreUrl(configs[0], configs[1],
      platform: defaultTargetPlatform);
});
