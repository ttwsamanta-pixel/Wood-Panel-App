import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import 'cached_content_repository.dart';
import 'content_repository.dart';
import 'download_repository.dart';
import 'hybrid_content_repository.dart';
import 'mock_content_repository.dart';
import 'wordpress_content_repository.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  return DownloadRepository(ref.watch(apiClientProvider).dio);
});

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return CachedContentRepository(
    inner: HybridContentRepository(
      remote: WordPressContentRepository(ref.watch(apiClientProvider)),
      fallback: mockContentRepository,
    ),
  );
});
