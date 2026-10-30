import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/edition/edition.dart';
import 'cached_content_repository.dart';
import 'content_repository.dart';
import 'download_repository.dart';
import 'wordpress_content_repository.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(baseUrl: ref.watch(editionProvider).site);
  ref.onDispose(() => client.dio.close(force: true));
  return client;
});

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  return DownloadRepository(ref.watch(apiClientProvider).dio,
      edition: ref.watch(editionProvider).name);
});

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  final edition = ref.watch(editionProvider);
  var active = true;
  ref.onDispose(() => active = false);
  return CachedContentRepository(
    edition: edition.name,
    inner: WordPressContentRepository(ref.watch(apiClientProvider),
        config: ref.watch(activeConfigProvider)),
    isActive: () => active,
  );
});
