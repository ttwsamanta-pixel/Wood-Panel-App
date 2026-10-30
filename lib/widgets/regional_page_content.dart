import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/repositories/content_providers.dart';

final regionalPageProvider =
    FutureProvider.family<String, int>((ref, id) async {
  final json = await ref.watch(apiClientProvider).get<Map<String, dynamic>>(
      '/wp-json/wp/v2/pages/$id',
      queryParameters: {'_fields': 'content'});
  return (json['content'] as Map?)?['rendered'] as String? ?? '';
});

class RegionalPageContent extends ConsumerWidget {
  const RegionalPageContent({super.key, required this.pageId});
  final int pageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (pageId == 0) return const SizedBox.shrink();
    return ref.watch(regionalPageProvider(pageId)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => TextButton(
              onPressed: () => ref.invalidate(regionalPageProvider(pageId)),
              child: const Text('Retry page content')),
          data: (html) => HtmlWidget(html, onTapUrl: (url) async {
            final uri = Uri.tryParse(url);
            if (uri == null || !['https', 'mailto', 'tel'].contains(uri.scheme)) {
              return false;
            }
            return launchUrl(uri, mode: LaunchMode.externalApplication);
          }),
        );
  }
}
