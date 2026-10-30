import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';

// Use the same disk and decoded-image caches as the visible banners. Start
// while configuration is being refreshed, before the destination page builds.
class BannerPreloader {
  static final Set<String> _pending = {};
  static final List<String> _queue = [];
  static int _active = 0;

  static void warm(Iterable<String> urls) {
    for (final url in urls) {
      if (Uri.tryParse(url)?.scheme == 'https' && _pending.add(url)) {
        _queue.add(url);
      }
    }
    _drain();
  }

  static void _drain() {
    while (_active < 2 && _queue.isNotEmpty) {
      final url = _queue.removeAt(0);
      _active++;
      unawaited(_load(url).whenComplete(() {
        _active--;
        _pending.remove(url);
        _drain();
      }));
    }
  }

  static Future<void> _load(String url) async {
    final done = Completer<void>();
    ImageStream? stream;
    ImageStreamListener? listener;
    try {
      stream =
          CachedNetworkImageProvider(url).resolve(const ImageConfiguration());
      listener = ImageStreamListener((image, synchronousCall) {
        image.dispose();
        if (!done.isCompleted) done.complete();
      }, onError: (Object error, StackTrace? stack) {
        if (!done.isCompleted) done.complete();
      });
      stream.addListener(listener);
      await done.future.timeout(const Duration(seconds: 20), onTimeout: () {});
    } catch (_) {
      // Failed ads must not prevent configuration or content from loading.
    } finally {
      if (listener != null) stream?.removeListener(listener);
    }
  }
}
