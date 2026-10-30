import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'edition.dart';

final adAnalyticsProvider = Provider<AdAnalytics>((ref) {
  final analytics = AdAnalytics();
  ref.onDispose(analytics.dispose);
  return analytics;
});
String newAdViewId() => List.generate(16, (_) => Random.secure().nextInt(256))
    .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
    .join();

// One continuous foreground exposure with at least 50% visible.
class AdExposure {
  String viewId = newAdViewId();
  DateTime? _since;
  bool impressed = false, clicked = false;
  bool sample(bool eligible, DateTime now) {
    if (!eligible) {
      if (_since != null) {
        viewId = newAdViewId();
        impressed = false;
        clicked = false;
      }
      _since = null;
      return false;
    }
    _since ??= now;
    if (!impressed && now.difference(_since!) >= const Duration(seconds: 1)) {
      impressed = true;
      return true;
    }
    return false;
  }
}

class AdAnalytics {
  AdAnalytics({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 5),
                sendTimeout: const Duration(seconds: 5),
                followRedirects: false));
  final Dio _dio;
  void dispose() => _dio.close(force: true);
  Future<void> record(Edition edition, Map<String, String> banner,
      String viewId, String type) async {
    final url = Uri.tryParse(banner['tracking_url'] ?? '');
    if (url == null ||
        url.scheme != 'https' ||
        Edition.forHost(url.host) != edition ||
        url.path != '/wp-json/wood-panel-app/v1/ad-event' ||
        (banner['tracking_token'] ?? '').isEmpty ||
        int.tryParse(banner['id'] ?? '') == null) {
      return;
    }
    final data = {
      'banner_id': banner['id'],
      'placement': banner['placement'],
      'token': banner['tracking_token'],
      'view_id': viewId,
      'type': type
    };
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _dio.post<void>(url.toString(), data: data);
        return;
      } on DioException catch (error) {
        if (error.response != null &&
            (error.response!.statusCode ?? 500) < 500) {
          return;
        }
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      } catch (_) {
        return;
      }
    }
  }
}
