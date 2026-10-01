import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import 'content_repository.dart';
import 'hybrid_content_repository.dart';
import 'mock_content_repository.dart';
import 'wordpress_content_repository.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return HybridContentRepository(
    remote: WordPressContentRepository(ref.watch(apiClientProvider)),
    fallback: mockContentRepository,
  );
});
