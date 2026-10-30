import 'notification_inbox.dart';
import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../routing/app_router.dart';
import '../network/api_client.dart';
import 'edition.dart';

final notificationsEnabledProvider = StateProvider<bool>((ref) => false);
final notificationStatusProvider =
    StateProvider<String>((ref) => 'Notifications are not configured yet.');
final editionNavigationProvider = Provider<EditionNavigation>((ref) {
  final service = EditionNavigation(ref);
  ref.onDispose(service.dispose);
  ref.listen(editionProvider, (_, __) => service.syncTopics());
  ref.listen(notificationsEnabledProvider, (_, __) => service.syncTopics());
  unawaited(service.start());
  return service;
});

class EditionNavigation {
  EditionNavigation(this.ref);
  final Ref ref;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  bool _disposed = false;
  bool _firebaseReady = false;
  int _navigationVersion = 0;
  Future<void> _topicQueue = Future.value();

  Future<void> start() async {
    _subscriptions
        .add(AppLinks().uriLinkStream.listen(openLink, onError: (_) {}));
    final prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    ref.read(notificationsEnabledProvider.notifier).state =
        prefs.getBool('push_enabled') ?? false;
    // Firebase public app identifiers are supplied by the deployment, never guessed.
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const project = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const sender = String.fromEnvironment('FIREBASE_SENDER_ID');
    final hasExplicitOptions =
        [appId, apiKey, project, sender].every((value) => value.isNotEmpty);
    final usesNativeConfiguration = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (!hasExplicitOptions && !usesNativeConfiguration) return;
    try {
      if (hasExplicitOptions) {
        await Firebase.initializeApp(
            options: const FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: sender,
          projectId: project,
          iosBundleId: String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
        ));
      } else {
        // Android reads google-services.json through generated resources;
        // iOS reads GoogleService-Info.plist from the application bundle.
        await Firebase.initializeApp();
      }
      if (_disposed) return;
      _firebaseReady = true;
      ref.read(notificationStatusProvider.notifier).state =
          'Receive news from the selected edition.';
      _subscriptions
          .add(FirebaseMessaging.onMessageOpenedApp.listen(_openMessage));
      _subscriptions.add(
          FirebaseMessaging.instance.onRegistered.listen((_) => syncTopics()));
      _subscriptions.add(FirebaseMessaging.onMessage.listen((message) {
        if (_disposed ||
            message.data['edition'] != ref.read(editionProvider).name) {
          return;
        }
        ref
            .read(notificationInboxProvider(ref.read(editionProvider)).notifier)
            .refresh();
        final context = ref
            .read(appRouterProvider)
            .routerDelegate
            .navigatorKey
            .currentContext;
        if (context == null || !context.mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          content: Text(message.notification?.title ?? 'Wood & Panel news'),
          action: SnackBarAction(
              label: 'Read', onPressed: () => _openMessage(message)),
        ));
      }));
      final message = await FirebaseMessaging.instance.getInitialMessage();
      if (_disposed) return;
      if (message != null) _openMessage(message);
      syncTopics();
    } catch (_) {
      if (!_disposed) {
        ref.read(notificationStatusProvider.notifier).state =
            'Notifications are temporarily unavailable.';
      }
    }
  }

  void _openMessage(RemoteMessage message) {
    final edition = switch (message.data['edition']) {
      'europe' => Edition.europe,
      'usa' => Edition.usa,
      _ => null,
    };
    final id = int.tryParse('${message.data['article_id']}');
    if (edition != null && id != null && id > 0) {
      final notificationId = message.data['notification_id'];
      if (notificationId != null) {
        ref
            .read(notificationInboxProvider(edition).notifier)
            .markRead('$notificationId');
      }
      ref.read(notificationInboxProvider(edition).notifier).refresh();
      openLink(Uri.parse('${edition.site}/?p=$id'));
    }
  }

  Future<void> openLink(Uri uri) async {
    if (_disposed || uri.scheme != 'https') return;
    final edition = Edition.forHost(uri.host);
    if (edition == null) return;
    final version = ++_navigationVersion;
    final router = ref.read(appRouterProvider);
    ref.read(editionProvider.notifier).state = edition;
    router.go('/home');
    await ref.read(editionConfigProvider(edition).future);
    if (_disposed ||
        version != _navigationVersion ||
        ref.read(editionProvider) != edition) {
      return;
    }
    var id = int.tryParse(uri.queryParameters['p'] ?? '');
    if (id == null && uri.pathSegments.where((s) => s.isNotEmpty).isNotEmpty) {
      final client = ApiClient(baseUrl: edition.site);
      try {
        final slug = uri.pathSegments.lastWhere((s) => s.isNotEmpty);
        final posts = await client.get<List<dynamic>>('/wp-json/wp/v2/posts',
            queryParameters: {'slug': slug, '_fields': 'id', 'per_page': 1});
        if (posts.isNotEmpty) id = (posts.first['id'] as num).toInt();
      } catch (_) {
        /* Leave the selected edition home open on unavailable links. */
      } finally {
        client.dio.close();
      }
    }
    if (!_disposed &&
        version == _navigationVersion &&
        ref.read(editionProvider) == edition &&
        id != null &&
        id > 0) {
      router.go('/article/$id');
    }
  }

  Future<void> setEnabled(bool enabled) async {
    if (!_firebaseReady) return;
    if (enabled) {
      final permission = await FirebaseMessaging.instance.requestPermission();
      enabled =
          permission.authorizationStatus == AuthorizationStatus.authorized ||
              permission.authorizationStatus == AuthorizationStatus.provisional;
    }
    if (_disposed) return;
    ref.read(notificationsEnabledProvider.notifier).state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_enabled', enabled);
  }

  void syncTopics() {
    if (_disposed || !_firebaseReady) return;
    // Serialize topic updates so rapid edition switches cannot subscribe out of order.
    _topicQueue = _topicQueue.then((_) async {
      if (_disposed) return;
      final edition = ref.read(editionProvider);
      final enabled = ref.read(notificationsEnabledProvider);
      await FirebaseMessaging.instance.setAutoInitEnabled(enabled);
      for (final item in Edition.values) {
        if (!enabled || item != edition) {
          await FirebaseMessaging.instance.unsubscribeFromTopic(item.topic);
        }
      }
      if (enabled) {
        await FirebaseMessaging.instance.subscribeToTopic(edition.topic);
      }
      if (!_disposed) {
        ref.read(notificationStatusProvider.notifier).state = enabled
            ? '${edition.label} notifications enabled.'
            : 'Notifications are off.';
      }
    }).catchError((Object _) {
      if (!_disposed) {
        ref.read(notificationStatusProvider.notifier).state =
            'Unable to update notifications. Please try again.';
      }
    });
  }

  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
  }
}

void showNotificationSettings(BuildContext context) {
  showDialog<void>(
      context: context,
      builder: (_) => Consumer(
          builder: (context, ref, _) => AlertDialog(
                title: const Text('Notifications'),
                content: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title:
                      Text('Wood & Panel ${ref.watch(editionProvider).label}'),
                  subtitle: Text(ref.watch(notificationStatusProvider)),
                  value: ref.watch(notificationsEnabledProvider),
                  onChanged: (value) =>
                      ref.read(editionNavigationProvider).setEnabled(value),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'))
                ],
              )));
}
