import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/edition/edition.dart';
import '../../core/edition/edition_navigation.dart';
import '../../data/repositories/content_providers.dart';
import '../home/home_screen.dart' show showNewsletterPopup;

Future<void> openProfileAction(
    BuildContext context, WidgetRef ref, String route) async {
  if (route == 'newsletter') {
    var cover = '';
    try {
      final issues = await ref.read(contentRepositoryProvider).magazines();
      if (issues.isNotEmpty) cover = issues.first.coverUrl;
    } catch (_) {}
    if (context.mounted) await showNewsletterPopup(context, cover);
  } else if (route == 'rate' || route == 'share') {
    final url = await ref.read(sharedAppStoreUrlProvider.future);
    if (!context.mounted) return;
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App store link coming soon.')));
      return;
    }
    if (route == 'share') {
      await Share.share('Wood & Panel - $url');
    } else {
      try {
        final opened = await launchUrl(Uri.parse(url),
            mode: LaunchMode.externalApplication);
        if (!opened && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text('Could not open the app store. Please try again.')));
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text('Could not open the app store. Please try again.')));
        }
      }
    }
  } else if (route == 'notifications') {
    showNotificationSettings(context);
  } else {
    context.push(route);
  }
}
