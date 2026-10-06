import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/news_category.dart';
import '../../data/repositories/app_api_repository.dart';
import '../../data/repositories/app_preferences_repository.dart';
import '../../data/repositories/bookmark_repository.dart';
import '../../data/models/content_models.dart';
import '../../data/repositories/cache_refresh_bus.dart';
import '../../data/repositories/content_providers.dart';
import '../../data/repositories/download_repository.dart';
import '../../data/repositories/youtube_video_repository.dart';
import '../../widgets/wp_components.dart';
import '../../widgets/wp_scaffold.dart';

enum _ExploreTab { news, category, interviews, video }

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  static const _newsPerPage = 12;
  static const _interviewsPerPage = 12;

  var _selectedTab = _ExploreTab.news;
  var _query = '';
  final _contentScrollController = ScrollController();
  final List<Article> _newsArticles = [];
  final List<Article> _interviewArticles = [];
  late Future<List<YouTubeVideo>> _videosFuture;
  var _newsPage = 1;
  var _isNewsLoading = true;
  var _isNewsLoadingMore = false;
  var _hasMoreNews = true;
  var _interviewsPage = 1;
  var _isInterviewsLoading = true;
  var _isInterviewsLoadingMore = false;
  var _hasMoreInterviews = true;
  String? _newsError;
  String? _interviewsError;
  StreamSubscription<CacheRefreshType>? _cacheRefreshSubscription;

  @override
  void initState() {
    super.initState();
    _contentScrollController.addListener(_onContentScroll);
    _loadFirstNewsPage();
    _loadFirstInterviewsPage();
    _videosFuture =
        ref.read(youtubeVideoRepositoryProvider).latestVideos(limit: 50);
    _cacheRefreshSubscription = CacheRefreshBus.stream.listen((type) {
      if (!mounted) return;
      if (type == CacheRefreshType.content) {
        unawaited(_refreshExploreContentFromCache());
      } else if (type == CacheRefreshType.videos) {
        setState(() {
          _videosFuture =
              ref.read(youtubeVideoRepositoryProvider).latestVideos(limit: 50);
        });
      }
    });
  }

  @override
  void dispose() {
    _cacheRefreshSubscription?.cancel();
    _contentScrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshExploreContentFromCache() async {
    try {
      final news = await ref
          .read(contentRepositoryProvider)
          .latestArticles(page: 1, perPage: _newsPerPage);
      final interviews = await ref
          .read(contentRepositoryProvider)
          .latestInterviews(page: 1, perPage: _interviewsPerPage);
      if (!mounted) return;
      setState(() {
        if (news.isNotEmpty) {
          _newsPage = 1;
          _newsArticles
            ..clear()
            ..addAll(news);
          _hasMoreNews = news.length == _newsPerPage;
          _newsError = null;
          _isNewsLoading = false;
        }
        final preserveScrolledInterviews =
            _selectedTab == _ExploreTab.interviews &&
                _contentScrollController.hasClients &&
                _contentScrollController.position.pixels > 80;
        if (interviews.isNotEmpty && !preserveScrolledInterviews) {
          _interviewsPage = 1;
          _interviewArticles
            ..clear()
            ..addAll(interviews);
          _hasMoreInterviews = true;
          _interviewsError = null;
          _isInterviewsLoading = false;
        }
      });
    } on Object {
      // Keep current on-screen content if the refreshed cache cannot be read.
    }
  }

  void _onContentScroll() {
    if (_query.trim().isNotEmpty) {
      return;
    }
    if (!_contentScrollController.hasClients) {
      return;
    }
    final position = _contentScrollController.position;
    if (position.pixels >= position.maxScrollExtent - 520) {
      if (_selectedTab == _ExploreTab.news) {
        _loadNextNewsPage();
      } else if (_selectedTab == _ExploreTab.interviews) {
        _loadNextInterviewsPage();
      }
    }
  }

  Future<void> _loadFirstNewsPage() async {
    setState(() {
      _newsPage = 1;
      _newsArticles.clear();
      _isNewsLoading = true;
      _isNewsLoadingMore = false;
      _hasMoreNews = true;
      _newsError = null;
    });
    try {
      final articles = await ref
          .read(contentRepositoryProvider)
          .latestArticles(page: 1, perPage: _newsPerPage);
      if (!mounted) return;
      setState(() {
        _newsArticles.addAll(articles);
        _hasMoreNews = articles.length == _newsPerPage;
        _isNewsLoading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _newsError = 'Please check your connection and try again.';
        _isNewsLoading = false;
      });
    }
  }

  Future<void> _loadNextNewsPage() async {
    if (!_hasMoreNews || _isNewsLoadingMore || _isNewsLoading) {
      return;
    }
    setState(() => _isNewsLoadingMore = true);
    try {
      final nextPage = _newsPage + 1;
      final articles = await ref
          .read(contentRepositoryProvider)
          .latestArticles(page: nextPage, perPage: _newsPerPage);
      if (!mounted) return;
      final existingIds = _newsArticles.map((article) => article.id).toSet();
      final fresh =
          articles.where((article) => existingIds.add(article.id)).toList();
      setState(() {
        _newsPage = nextPage;
        _newsArticles.addAll(fresh);
        _hasMoreNews = articles.length == _newsPerPage && fresh.isNotEmpty;
        _isNewsLoadingMore = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _hasMoreNews = false;
        _isNewsLoadingMore = false;
      });
    }
  }

  Future<void> _loadFirstInterviewsPage() async {
    setState(() {
      _interviewsPage = 1;
      _interviewArticles.clear();
      _isInterviewsLoading = true;
      _isInterviewsLoadingMore = false;
      _hasMoreInterviews = true;
      _interviewsError = null;
    });
    try {
      final articles = await ref
          .read(contentRepositoryProvider)
          .latestInterviews(page: 1, perPage: _interviewsPerPage);
      if (!mounted) return;
      setState(() {
        _interviewArticles.addAll(articles);
        _hasMoreInterviews = articles.isNotEmpty;
        _isInterviewsLoading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _interviewsError = 'Please check your connection and try again.';
        _isInterviewsLoading = false;
      });
    }
  }

  Future<void> _loadNextInterviewsPage() async {
    if (!_hasMoreInterviews ||
        _isInterviewsLoadingMore ||
        _isInterviewsLoading) {
      return;
    }
    setState(() => _isInterviewsLoadingMore = true);
    try {
      final nextPage = _interviewsPage + 1;
      final articles = await ref
          .read(contentRepositoryProvider)
          .latestInterviews(page: nextPage, perPage: _interviewsPerPage);
      if (!mounted) return;
      final existingUrls = _interviewArticles
          .map((article) => article.url.toLowerCase().trim())
          .toSet();
      final fresh = articles
          .where(
              (article) => existingUrls.add(article.url.toLowerCase().trim()))
          .toList();
      setState(() {
        _interviewsPage = nextPage;
        _interviewArticles.addAll(fresh);
        _hasMoreInterviews = fresh.isNotEmpty;
        _isInterviewsLoadingMore = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _hasMoreInterviews = false;
        _isInterviewsLoadingMore = false;
      });
    }
  }

  Future<void> _reload() async {
    await _loadFirstNewsPage();
    await _loadFirstInterviewsPage();
    setState(() {
      _videosFuture =
          ref.read(youtubeVideoRepositoryProvider).latestVideos(limit: 50);
    });
    await _videosFuture;
  }

  void _selectTab(_ExploreTab tab) {
    setState(() {
      _selectedTab = tab;
      _query = '';
    });
    if (_contentScrollController.hasClients) {
      _contentScrollController.jumpTo(0);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_contentScrollController.hasClients) {
        _contentScrollController.jumpTo(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WPScaffold(
      child: Column(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(color: Colors.white),
            child: Column(
              children: [
                _ExploreTabs(
                  selected: _selectedTab,
                  onChanged: _selectTab,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: _ExploreSearchField(
                    selectedTab: _selectedTab,
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                controller: _contentScrollController,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                children: [_buildSelectedContent()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedContent() {
    return switch (_selectedTab) {
      _ExploreTab.news => _ExploreNewsList(
          articles: _newsArticles,
          isLoading: _isNewsLoading,
          isLoadingMore: _isNewsLoadingMore,
          error: _newsError,
          query: _query,
          onRetry: _loadFirstNewsPage,
        ),
      _ExploreTab.category => _ExploreCategoryGrid(query: _query),
      _ExploreTab.interviews => _ExploreInterviewsList(
          articles: _interviewArticles,
          isLoading: _isInterviewsLoading,
          isLoadingMore: _isInterviewsLoadingMore,
          error: _interviewsError,
          query: _query,
          onRetry: _loadFirstInterviewsPage,
        ),
      _ExploreTab.video => FutureBuilder<List<YouTubeVideo>>(
          future: _videosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _ExploreLoadingList(itemCount: 4);
            }
            if (snapshot.hasError) {
              return WPErrorState(
                title: 'Videos could not load',
                message: 'Please check your connection and try again.',
                onRetry: _reload,
              );
            }
            final videos =
                _filterVideos(snapshot.data ?? const <YouTubeVideo>[]);
            if (videos.isEmpty) {
              return const WPEmptyState(
                icon: Icons.play_circle_outline_rounded,
                title: 'No videos yet',
                message: 'Wood & Panel videos will appear here.',
              );
            }
            return Column(
              children: [
                for (final video in videos) _YouTubeVideoCard(video: video),
              ],
            );
          },
        ),
    };
  }

  List<YouTubeVideo> _filterVideos(List<YouTubeVideo> videos) {
    final normalized = _query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return videos;
    }
    return videos
        .where((video) =>
            video.title.toLowerCase().contains(normalized) ||
            video.description.toLowerCase().contains(normalized))
        .toList();
  }
}

class _ExploreTabs extends StatelessWidget {
  const _ExploreTabs({required this.selected, required this.onChanged});

  final _ExploreTab selected;
  final ValueChanged<_ExploreTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = [
      (_ExploreTab.news, 'News'),
      (_ExploreTab.category, 'Categories'),
      (_ExploreTab.interviews, 'Interviews'),
      (_ExploreTab.video, 'Videos'),
    ];
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 6, 5, 0),
        child: Row(
          children: [
            for (final item in items)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.zero,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => onChanged(item.$1),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 42,
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                item.$2,
                                maxLines: 1,
                                style: TextStyle(
                                  color: selected == item.$1
                                      ? AppColors.copper
                                      : AppColors.muted,
                                  fontSize: 13.5,
                                  fontWeight: selected == item.$1
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 3,
                          width: selected == item.$1 ? 44 : 0,
                          decoration: BoxDecoration(
                            color: AppColors.copper,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExploreSearchField extends StatelessWidget {
  const _ExploreSearchField({
    required this.selectedTab,
    required this.onChanged,
  });

  final _ExploreTab selectedTab;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: ValueKey(selectedTab),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search ${_tabLabel(selectedTab).toLowerCase()}...',
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: const Color(0xFFF7F1EC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  String _tabLabel(_ExploreTab tab) {
    return switch (tab) {
      _ExploreTab.news => 'News',
      _ExploreTab.category => 'Categories',
      _ExploreTab.interviews => 'Interviews',
      _ExploreTab.video => 'Videos',
    };
  }
}

class _ExploreLoadingList extends StatelessWidget {
  const _ExploreLoadingList({required this.itemCount});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 360,
      child: WPBrandLoader(label: 'Loading...'),
    );
  }
}

class _ExploreNewsList extends StatelessWidget {
  const _ExploreNewsList({
    required this.articles,
    required this.isLoading,
    required this.isLoadingMore,
    required this.error,
    required this.query,
    required this.onRetry,
  });

  final List<Article> articles;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String query;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _ExploreLoadingList(itemCount: 5);
    }
    if (error != null) {
      return WPErrorState(
        title: 'News could not load',
        message: error!,
        onRetry: onRetry,
      );
    }
    final filteredArticles = _filterArticles(articles);
    if (filteredArticles.isEmpty) {
      return const WPEmptyState(
        icon: Icons.article_outlined,
        title: 'No news found',
        message: 'Try another search term.',
      );
    }
    return Column(
      children: [
        for (final article in filteredArticles)
          _ExploreArticleCard(article: article),
        if (isLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: WPBrandLoader(size: 64, compact: true),
          ),
      ],
    );
  }

  List<Article> _filterArticles(List<Article> articles) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return articles;
    }
    return articles
        .where((article) =>
            article.title.toLowerCase().contains(normalized) ||
            article.excerpt.toLowerCase().contains(normalized) ||
            article.category.toLowerCase().contains(normalized))
        .toList();
  }
}

class _ExploreInterviewsList extends ConsumerWidget {
  const _ExploreInterviewsList({
    required this.articles,
    required this.isLoading,
    required this.isLoadingMore,
    required this.error,
    required this.query,
    required this.onRetry,
  });

  final List<Article> articles;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String query;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isLoading) {
      return const _ExploreLoadingList(itemCount: 5);
    }
    if (error != null) {
      return WPErrorState(
        title: 'Interviews could not load',
        message: error!,
        onRetry: onRetry,
      );
    }
    final filteredArticles = _filterArticles(articles);
    if (filteredArticles.isEmpty) {
      return const WPEmptyState(
        icon: Icons.record_voice_over_outlined,
        title: 'No interviews found',
        message: 'Try another search term.',
      );
    }
    final featured = filteredArticles.first;
    final rest = filteredArticles.skip(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FeaturedInterviewCard(article: featured),
        const SizedBox(height: 16),
        Text(
          'All Interviews',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 10),
        for (final article in rest)
          _ExploreArticleCard(
            article: article,
            imageHeight: article.id > 0 ? 178 : 230,
            imageFit: article.id > 0 ? BoxFit.cover : BoxFit.contain,
            dateText: article.id > 0
                ? DateFormat('d MMM yyyy').format(article.date)
                : 'Interview',
            onTap: () => _openInterview(context, article),
          ),
        if (isLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: WPBrandLoader(size: 64, compact: true),
          ),
      ],
    );
  }

  List<Article> _filterArticles(List<Article> articles) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return articles;
    }
    return articles
        .where((article) =>
            article.title.toLowerCase().contains(normalized) ||
            article.excerpt.toLowerCase().contains(normalized) ||
            article.category.toLowerCase().contains(normalized))
        .toList();
  }
}

class _FeaturedInterviewCard extends StatelessWidget {
  const _FeaturedInterviewCard({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openInterview(context, article),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                WPImage(
                  url: article.imageUrl,
                  height: 210,
                  width: double.infinity,
                  borderRadius: 0,
                ),
                Positioned(
                  left: 14,
                  top: 14,
                  child: WPTag('Latest Interview'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          height: 1.08,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article.excerpt,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 15,
                      height: 1.28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined,
                          size: 17, color: AppColors.muted),
                      const SizedBox(width: 5),
                      Text(
                        DateFormat('d MMM yyyy').format(article.date),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Share',
                        color: AppColors.copper,
                        icon: const Icon(Icons.share_rounded),
                        onPressed: () =>
                            Share.share('${article.title}\n${article.url}'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExploreCategoryGrid extends StatelessWidget {
  const _ExploreCategoryGrid({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final categories = _filterCategories();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.38,
      ),
      itemBuilder: (context, index) {
        final category = categories[index];
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.push('/category/${category.id}'),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F1EC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_categoryIcon(category.id), color: AppColors.copper),
                const Spacer(),
                Text(
                  category.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<NewsCategory> _filterCategories() {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return NewsCategory.all;
    }
    return NewsCategory.all
        .where((category) => category.name.toLowerCase().contains(normalized))
        .toList();
  }

  IconData _categoryIcon(int id) {
    return switch (id) {
      30036 => Icons.new_releases_rounded,
      27527 => Icons.handyman_rounded,
      31124 => Icons.event_available_rounded,
      33793 => Icons.business_center_rounded,
      33794 => Icons.eco_rounded,
      33795 => Icons.chair_rounded,
      31111 => Icons.format_paint_rounded,
      33796 => Icons.palette_rounded,
      31112 => Icons.computer_rounded,
      31118 => Icons.forest_rounded,
      33797 => Icons.layers_rounded,
      33798 => Icons.grid_on_rounded,
      31115 => Icons.construction_rounded,
      33799 => Icons.precision_manufacturing_rounded,
      _ => Icons.article_rounded,
    };
  }
}

class _ExploreArticleCard extends ConsumerStatefulWidget {
  const _ExploreArticleCard({
    required this.article,
    this.onTap,
    this.imageHeight = 132,
    this.imageFit = BoxFit.cover,
    this.dateText,
  });

  final Article article;
  final VoidCallback? onTap;
  final double imageHeight;
  final BoxFit imageFit;
  final String? dateText;

  @override
  ConsumerState<_ExploreArticleCard> createState() =>
      _ExploreArticleCardState();
}

class _ExploreArticleCardState extends ConsumerState<_ExploreArticleCard> {
  var _isBookmarked = false;

  Article get article => widget.article;

  @override
  void initState() {
    super.initState();
    _loadBookmark();
  }

  @override
  void didUpdateWidget(covariant _ExploreArticleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.article.id != widget.article.id) {
      _loadBookmark();
    }
  }

  Future<void> _loadBookmark() async {
    final isBookmarked =
        await ref.read(bookmarkRepositoryProvider).isBookmarked(article.id);
    if (mounted) {
      setState(() => _isBookmarked = isBookmarked);
    }
  }

  Future<void> _toggleBookmark() async {
    final next = !_isBookmarked;
    setState(() => _isBookmarked = next);
    await ref
        .read(bookmarkRepositoryProvider)
        .setArticleBookmark(article.id, next);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap ?? () => context.push('/article/${article.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                WPImage(
                  url: article.imageUrl,
                  height: widget.imageHeight,
                  width: double.infinity,
                  fit: widget.imageFit,
                  borderRadius: 0,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wood & Panel  •  ${widget.dateText ?? DateFormat("d MMM yyyy").format(article.date)}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          height: 1.08,
                          fontSize: 20,
                        ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    article.excerpt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      height: 1.25,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.headphones_rounded, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        '${article.readingMinutes} min read',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Share',
                        icon: const Icon(Icons.share_rounded),
                        onPressed: () =>
                            Share.share('${article.title}\n${article.url}'),
                      ),
                      IconButton(
                        tooltip: 'Bookmark',
                        icon: Icon(_isBookmarked
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded),
                        onPressed: _toggleBookmark,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with SingleTickerProviderStateMixin {
  static const _perPage = 10;

  final _pageController = PageController();
  late final AnimationController _swipeHintController;
  late final Animation<double> _swipeNudge;
  Timer? _swipeHintTimer;
  final List<Article> _articles = [];
  var _page = 1;
  var _isLoading = true;
  var _isLoadingMore = false;
  var _hasMore = true;
  var _showSwipeHint = false;
  String? _error;
  StreamSubscription<CacheRefreshType>? _cacheRefreshSubscription;

  @override
  void initState() {
    super.initState();
    _swipeHintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    )..repeat(reverse: true);
    _swipeNudge = CurvedAnimation(
      parent: _swipeHintController,
      curve: Curves.easeInOutCubic,
    ).drive(Tween<double>(begin: 0, end: -26));
    _loadFirstPage();
    _cacheRefreshSubscription = CacheRefreshBus.stream.listen((type) {
      if (type == CacheRefreshType.content && mounted) {
        unawaited(_refreshFirstPageFromCache());
      }
    });
  }

  @override
  void dispose() {
    _cacheRefreshSubscription?.cancel();
    _swipeHintTimer?.cancel();
    _swipeHintController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _hideSwipeHint() {
    if (!_showSwipeHint) {
      return;
    }
    _swipeHintTimer?.cancel();
    _swipeHintController.stop();
    setState(() => _showSwipeHint = false);
  }

  void _startSwipeHint() {
    _swipeHintTimer?.cancel();
    _swipeHintController.repeat(reverse: true);
    setState(() => _showSwipeHint = true);
    _swipeHintTimer = Timer(const Duration(seconds: 12), () {
      if (mounted && _showSwipeHint) {
        _hideSwipeHint();
      }
    });
  }

  void _onPageChanged(int index) {
    if (_showSwipeHint) {
      _hideSwipeHint();
    }
    if (_hasMore && !_isLoadingMore && index >= _articles.length - 3) {
      _loadNextPage();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _page = 1;
      _isLoading = true;
      _isLoadingMore = false;
      _hasMore = true;
      _error = null;
    });

    try {
      final items = await ref
          .read(contentRepositoryProvider)
          .latestArticles(page: 1, perPage: _perPage);
      if (!mounted) return;
      setState(() {
        _articles
          ..clear()
          ..addAll(items);
        _hasMore = items.length == _perPage;
        _isLoading = false;
      });
      if (items.isNotEmpty) {
        _startSwipeHint();
      }
    } on Object {
      if (!mounted) return;
      setState(() {
        _error = 'Please check your connection and try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    if (!_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _page + 1;
      final items = await ref
          .read(contentRepositoryProvider)
          .latestArticles(page: nextPage, perPage: _perPage);
      if (!mounted) return;
      final existingIds = _articles.map((article) => article.id).toSet();
      final newItems =
          items.where((article) => existingIds.add(article.id)).toList();
      setState(() {
        _page = nextPage;
        _articles.addAll(newItems);
        _hasMore = items.length == _perPage && newItems.isNotEmpty;
        _isLoadingMore = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _hasMore = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refreshFirstPageFromCache() async {
    try {
      final items = await ref
          .read(contentRepositoryProvider)
          .latestArticles(page: 1, perPage: _perPage);
      if (!mounted || items.isEmpty) return;
      setState(() {
        _page = 1;
        _articles
          ..clear()
          ..addAll(items);
        _hasMore = items.length == _perPage;
        _isLoading = false;
        _error = null;
      });
    } on Object {
      // Keep the visible feed if the refreshed cache cannot be read.
    }
  }

  @override
  Widget build(BuildContext context) {
    return WPScaffold(
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const WPSkeletonList(itemCount: 6);
    }
    if (_error != null) {
      return WPErrorState(
        title: 'Feed could not load',
        message: _error!,
        onRetry: _loadFirstPage,
      );
    }
    if (_articles.isEmpty) {
      return const WPEmptyState(
        icon: Icons.dynamic_feed_outlined,
        title: 'No feed stories yet',
        message: 'Fresh Wood And Panel stories will appear here.',
      );
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          onPageChanged: _onPageChanged,
          itemCount: _articles.length + 1,
          itemBuilder: (context, index) {
            if (index == _articles.length) {
              if (_isLoadingMore || _hasMore) {
                return const WPBrandLoader(size: 82, compact: true);
              }
              return const WPEmptyState(
                icon: Icons.done_all_rounded,
                title: 'You are all caught up',
                message:
                    'New published stories will appear here automatically.',
              );
            }
            final card = _FeedNewsCard(article: _articles[index]);
            if (index != 0 || !_showSwipeHint) {
              return card;
            }
            return AnimatedBuilder(
              animation: _swipeNudge,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _swipeNudge.value),
                  child: child,
                );
              },
              child: card,
            );
          },
        ),
        if (_showSwipeHint)
          Positioned(
            right: 20,
            bottom: 96,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _swipeNudge,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _swipeNudge.value * .45),
                    child: child,
                  );
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: .82),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.keyboard_double_arrow_up_rounded,
                            color: Colors.white, size: 20),
                        SizedBox(width: 6),
                        Text(
                          'Swipe up',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FeedNewsCard extends ConsumerStatefulWidget {
  const _FeedNewsCard({required this.article});

  final Article article;

  @override
  ConsumerState<_FeedNewsCard> createState() => _FeedNewsCardState();
}

class _FeedNewsCardState extends ConsumerState<_FeedNewsCard> {
  var _isBookmarked = false;

  Article get article => widget.article;

  @override
  void initState() {
    super.initState();
    _loadBookmark();
  }

  @override
  void didUpdateWidget(covariant _FeedNewsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.article.id != widget.article.id) {
      _loadBookmark();
    }
  }

  Future<void> _loadBookmark() async {
    final isBookmarked =
        await ref.read(bookmarkRepositoryProvider).isBookmarked(article.id);
    if (mounted) {
      setState(() => _isBookmarked = isBookmarked);
    }
  }

  Future<void> _toggleBookmark() async {
    final next = !_isBookmarked;
    setState(() => _isBookmarked = next);
    await ref
        .read(bookmarkRepositoryProvider)
        .setArticleBookmark(article.id, next);
  }

  @override
  Widget build(BuildContext context) {
    final authorInitial = article.author.trim().isEmpty
        ? 'W'
        : article.author.trim()[0].toUpperCase();
    final hasAuthorAvatar = article.authorAvatarUrl.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/article/${article.id}'),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final imageHeight =
                  (constraints.maxHeight * .35).clamp(190.0, 265.0);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      WPImage(
                        url: article.imageUrl,
                        height: imageHeight,
                        width: double.infinity,
                        borderRadius: 0,
                      ),
                      Positioned(
                        top: 18,
                        left: 22,
                        child: WPTag(article.category),
                      ),
                      Positioned(
                        top: 18,
                        right: 18,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .48),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            tooltip: 'Open article',
                            color: Colors.white,
                            onPressed: () =>
                                context.push('/article/${article.id}'),
                            icon: const Icon(Icons.open_in_full_rounded),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            article.title,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontSize: 23,
                                  height: 1.04,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            article.excerpt,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: AppColors.muted,
                                      fontSize: 14.5,
                                      height: 1.28,
                                    ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: const Color(0xFFF8EBDD),
                                backgroundImage: hasAuthorAvatar
                                    ? NetworkImage(article.authorAvatarUrl)
                                    : null,
                                child: Text(
                                  hasAuthorAvatar ? '' : authorInitial,
                                  style: const TextStyle(
                                    color: AppColors.copper,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Written by',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color: AppColors.muted,
                                            fontSize: 12,
                                            height: 1,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      article.author,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: AppColors.green,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            height: 1.05,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                  width: 1, height: 38, color: AppColors.line),
                              const SizedBox(width: 8),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                      color: const Color(0xFFE6C9B2)),
                                ),
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(64, 38),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9),
                                  ),
                                  onPressed: _toggleBookmark,
                                  icon: Icon(
                                    _isBookmarked
                                        ? Icons.bookmark_rounded
                                        : Icons.bookmark_border_rounded,
                                    color: AppColors.copper,
                                  ),
                                  label: Text(
                                    _isBookmarked ? 'Saved' : 'Save',
                                    style: const TextStyle(
                                      color: AppColors.copper,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.calendar_month_outlined,
                                  size: 18, color: AppColors.muted),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('d MMM yyyy').format(article.date),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      color: AppColors.muted,
                                      fontSize: 13,
                                    ),
                              ),
                              Container(
                                width: 1,
                                height: 20,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                color: AppColors.line,
                              ),
                              const Icon(Icons.schedule_rounded,
                                  size: 18, color: AppColors.muted),
                              const SizedBox(width: 6),
                              Text(
                                '${article.readingMinutes} min read',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      color: AppColors.muted,
                                      fontSize: 13,
                                    ),
                              ),
                              const Spacer(),
                              DecoratedBox(
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFDF2E8),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  tooltip: 'Share',
                                  color: AppColors.copper,
                                  iconSize: 22,
                                  onPressed: () => Share.share(
                                      '${article.title}\n${article.url}'),
                                  icon: const Icon(Icons.share_rounded),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 44,
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.copper,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999)),
                              ),
                              onPressed: () =>
                                  context.push('/article/${article.id}'),
                              label: const Text(
                                'Read Full Article',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 15),
                              ),
                              icon: const Icon(Icons.arrow_forward_rounded),
                              iconAlignment: IconAlignment.end,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class MagazineScreen extends ConsumerWidget {
  const MagazineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(contentRepositoryProvider);
    return WPScaffold(
      child: FutureBuilder(
        future: repository.magazines(),
        builder: (context, snapshot) {
          final issues = snapshot.data ?? [];
          if (snapshot.connectionState != ConnectionState.done) {
            return const WPSkeletonList(itemCount: 5);
          }
          if (snapshot.hasError) {
            return const WPErrorState(
              title: 'Magazines could not load',
              message: 'Please check your connection and reopen Magazine.',
            );
          }
          if (issues.isEmpty) {
            return const WPEmptyState(
              icon: Icons.menu_book_outlined,
              title: 'No magazine issues yet',
              message: 'Digital magazine issues will appear here.',
            );
          }
          final latest = issues.first;
          final previous = issues.skip(1).take(8).toList();
          final archiveYears = issues
              .map((issue) => issue.date.year)
              .toSet()
              .toList()
            ..sort((a, b) => b.compareTo(a));
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            children: [
              _LatestMagazinePanel(issue: latest),
              if (previous.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text('Previous Issues',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                SizedBox(
                  height: 322,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: previous.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) =>
                        _MagazineIssueCard(issue: previous[index]),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Text('Year Wise Archive',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: archiveYears.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 184,
                ),
                itemBuilder: (context, index) {
                  final year = archiveYears[index];
                  return _ArchiveYearTile(
                    year: year,
                    issues: issues
                        .where((issue) => issue.date.year == year)
                        .toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LatestMagazinePanel extends StatelessWidget {
  const _LatestMagazinePanel({required this.issue});

  final MagazineIssue issue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F4EF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MagazineCoverImage(
            url: issue.coverUrl,
            height: 330,
            width: double.infinity,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.copper,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'LATEST ISSUE',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 10),
          Text(issue.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            issue.description,
            style: const TextStyle(color: AppColors.muted, height: 1.25),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MagazineMeta(icon: Icons.menu_book_rounded, label: 'Vol. 18'),
              const SizedBox(width: 12),
              _MagazineMeta(
                  icon: Icons.article_outlined,
                  label: 'Issue ${issue.date.month}'),
              const SizedBox(width: 12),
              const _MagazineMeta(icon: Icons.picture_as_pdf, label: 'PDF'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: WPPrimaryButton(
                  label: 'Read Now',
                  onPressed: () => context.push('/magazine/${issue.id}/read'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MagazinePdfActionButton(issue: issue),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MagazineCoverImage extends StatelessWidget {
  const _MagazineCoverImage({
    required this.url,
    required this.height,
    required this.width,
    this.framed = true,
  });

  final String url;
  final double height;
  final double width;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    if (!framed) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: WPImage(
          url: url,
          width: width,
          height: height,
          fit: BoxFit.contain,
        ),
      );
    }
    return Container(
      height: height,
      width: width,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: WPImage(
        url: url,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _MagazineDownloadButton extends StatelessWidget {
  const _MagazineDownloadButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.height = 48,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: Size.fromHeight(height),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 6),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MagazinePdfActionButton extends ConsumerWidget {
  const _MagazinePdfActionButton({
    required this.issue,
    this.compact = false,
  });

  final MagazineIssue issue;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (issue.pdfUrl.isEmpty) {
      return _MagazineDownloadButton(
        label: compact ? 'PDF' : 'Download PDF',
        icon: Icons.download_rounded,
        height: compact ? 34 : 48,
        onPressed: null,
      );
    }
    final repository = ref.watch(downloadRepositoryProvider);
    return FutureBuilder<DownloadedFile?>(
      future: repository.fileForUrl(issue.pdfUrl),
      builder: (context, snapshot) {
        final downloaded = snapshot.data;
        if (downloaded != null) {
          return _MagazineDownloadButton(
            label: compact ? 'View PDF' : 'View PDF',
            icon: Icons.visibility_outlined,
            height: compact ? 34 : 48,
            onPressed: () => _openDownloadedPdf(context, downloaded),
          );
        }
        return _MagazineDownloadButton(
          label: compact ? 'Download' : 'Download PDF',
          icon: Icons.download_rounded,
          height: compact ? 34 : 48,
          onPressed: () async {
            await _downloadMagazinePdf(context, issue);
            ref.invalidate(downloadRepositoryProvider);
          },
        );
      },
    );
  }
}

class _MagazineMeta extends StatelessWidget {
  const _MagazineMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.muted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.muted, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _MagazineIssueCard extends StatelessWidget {
  const _MagazineIssueCard({required this.issue});

  final MagazineIssue issue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => context.push('/magazine/${issue.id}'),
            child: _MagazineCoverImage(
              url: issue.coverUrl,
              height: 150,
              width: 170,
              framed: false,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            issue.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          Text(
            'Vol. 18 | Issue ${issue.date.month}',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: FilledButton.icon(
              onPressed: () => context.push('/magazine/${issue.id}/read'),
              icon: const Icon(Icons.menu_book_rounded, size: 18),
              label: const Text('Read'),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: _MagazinePdfActionButton(issue: issue, compact: true),
          ),
        ],
      ),
    );
  }
}

class _ArchiveYearTile extends StatelessWidget {
  const _ArchiveYearTile({required this.year, required this.issues});

  final int year;
  final List<MagazineIssue> issues;

  @override
  Widget build(BuildContext context) {
    final issue = issues.isEmpty ? null : issues.first;
    return InkWell(
      onTap: () => context.push('/magazine/archive/$year'),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: issue != null
                  ? WPImage(
                      url: issue.coverUrl,
                      width: double.infinity,
                      height: 88,
                      fit: BoxFit.contain,
                    )
                  : Container(
                      width: double.infinity,
                      height: 88,
                      color: const Color(0xFFF8F3EE),
                      child: const Icon(Icons.menu_book_rounded,
                          color: AppColors.copper),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              '$year',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              '${issues.length} issues',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Jan - Dec $year',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                height: 1.05,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MagazineArchiveScreen extends ConsumerWidget {
  const MagazineArchiveScreen({super.key, required this.year});

  final int year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(contentRepositoryProvider);
    return WPScaffold(
      child: FutureBuilder(
        future: repository.magazines(),
        builder: (context, snapshot) {
          final issues = (snapshot.data ?? const <MagazineIssue>[])
              .where((issue) => issue.date.year == year)
              .toList();
          if (snapshot.connectionState != ConnectionState.done) {
            return const WPSkeletonList(itemCount: 5);
          }
          if (snapshot.hasError) {
            return const WPErrorState(
              title: 'Archive could not load',
              message: 'Please check your connection and reopen Magazine.',
            );
          }
          if (issues.isEmpty) {
            return WPEmptyState(
              icon: Icons.menu_book_outlined,
              title: 'No $year issues found',
              message: 'This archive year has no magazine issues yet.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            children: [
              Text('Archive $year',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: issues.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.47,
                ),
                itemBuilder: (context, index) =>
                    _MagazineIssueCard(issue: issues[index]),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('My Bookmarks', Icons.bookmark_border_rounded, '/bookmarks'),
      ('Downloads', Icons.download_rounded, '/downloads'),
      ('Wallpapers', Icons.wallpaper_rounded, '/wallpapers'),
      ('My Magazine', Icons.menu_book_rounded, '/magazine'),
      ('Preferences', Icons.settings_outlined, '/preferences'),
      ('Contact Us', Icons.mail_outline_rounded, '/contact'),
      ('Grow With Us', Icons.handshake_rounded, '/grow-with-us'),
      ('About Us', Icons.info_outline_rounded, '/about'),
    ];
    return WPScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 26),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F1EC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 36,
                  backgroundColor: Color(0xFFF3DCCB),
                  child: Icon(Icons.person, size: 34, color: AppColors.copper),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('John Doe',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      const Text(
                        'john.doe@gmail.com',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.workspace_premium_rounded,
                    color: AppColors.gold, size: 30),
                const SizedBox(height: 8),
                const Text(
                  'Wood & Panel Premium',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 17),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Read all magazine issues, premium articles, interviews and reports.',
                  style: TextStyle(color: Colors.white70, height: 1.3),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 38,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.green,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => context.push('/subscribe'),
                    child: const Text('Subscribe'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.line),
              ),
              child: ListTile(
                leading: Icon(item.$2, color: AppColors.copper),
                title: Text(item.$1,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(item.$3),
              ),
            ),
        ],
      ),
    );
  }
}

class VideosScreen extends ConsumerStatefulWidget {
  const VideosScreen({super.key});

  @override
  ConsumerState<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends ConsumerState<VideosScreen> {
  late Future<List<YouTubeVideo>> _videosFuture;
  StreamSubscription<CacheRefreshType>? _cacheRefreshSubscription;

  @override
  void initState() {
    super.initState();
    _videosFuture = _fetchVideos();
    _cacheRefreshSubscription = CacheRefreshBus.stream.listen((type) {
      if (type == CacheRefreshType.videos && mounted) {
        setState(() => _videosFuture = _fetchVideos());
      }
    });
  }

  @override
  void dispose() {
    _cacheRefreshSubscription?.cancel();
    super.dispose();
  }

  Future<List<YouTubeVideo>> _fetchVideos() {
    return ref.read(youtubeVideoRepositoryProvider).latestVideos(limit: 50);
  }

  Future<void> _reloadVideos() async {
    setState(() => _videosFuture = _fetchVideos());
    await _videosFuture;
  }

  @override
  Widget build(BuildContext context) {
    return WPScaffold(
      showBack: true,
      title: 'Videos',
      child: FutureBuilder<List<YouTubeVideo>>(
        future: _videosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const WPSkeletonList(itemCount: 5);
          }
          if (snapshot.hasError) {
            return WPErrorState(
              title: 'Videos could not load',
              message: 'Please check your connection and try again.',
              onRetry: _reloadVideos,
            );
          }
          final videos = snapshot.data ?? const <YouTubeVideo>[];
          if (videos.isEmpty) {
            return const WPEmptyState(
              icon: Icons.play_circle_outline_rounded,
              title: 'No YouTube videos yet',
              message: 'Latest Wood & Panel videos will appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: _reloadVideos,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Wood & Panel YouTube',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Open channel',
                      icon: const Icon(Icons.open_in_new_rounded),
                      color: AppColors.copper,
                      onPressed: () =>
                          _openUrl(YouTubeVideoRepository.channelUrl),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final video in videos) _YouTubeVideoCard(video: video),
              ],
            ),
          );
        },
      ),
    );
  }
}

class CategoryNewsScreen extends ConsumerStatefulWidget {
  const CategoryNewsScreen({super.key, required this.categoryId});

  final int categoryId;

  @override
  ConsumerState<CategoryNewsScreen> createState() => _CategoryNewsScreenState();
}

class _CategoryNewsScreenState extends ConsumerState<CategoryNewsScreen> {
  static const _perPage = 12;

  final _scrollController = ScrollController();
  final List<Article> _articles = [];
  var _page = 1;
  var _isLoading = true;
  var _isLoadingMore = false;
  var _hasMore = true;
  String? _error;
  StreamSubscription<CacheRefreshType>? _cacheRefreshSubscription;

  NewsCategory get category => NewsCategory.byId(widget.categoryId);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
    _cacheRefreshSubscription = CacheRefreshBus.stream.listen((type) {
      if (type == CacheRefreshType.content && mounted) {
        unawaited(_refreshFirstPageFromCache());
      }
    });
  }

  @override
  void dispose() {
    _cacheRefreshSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 520) {
      _loadNextPage();
    }
  }

  Future<List<Article>> _fetchArticles({required int page}) {
    return ref.read(contentRepositoryProvider).articlesByCategory(
          categoryId: category.id,
          categoryName: category.name,
          page: page,
          perPage: _perPage,
        );
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _page = 1;
      _articles.clear();
      _isLoading = true;
      _isLoadingMore = false;
      _hasMore = true;
      _error = null;
    });
    try {
      final articles = await _fetchArticles(page: 1);
      if (!mounted) return;
      setState(() {
        _articles.addAll(articles);
        _hasMore = articles.length == _perPage;
        _isLoading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _error = 'Please check your connection and try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    if (!_hasMore || _isLoading || _isLoadingMore) {
      return;
    }
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final articles = await _fetchArticles(page: nextPage);
      if (!mounted) return;
      final existingIds = _articles.map((article) => article.id).toSet();
      final fresh =
          articles.where((article) => existingIds.add(article.id)).toList();
      setState(() {
        _page = nextPage;
        _articles.addAll(fresh);
        _hasMore = articles.length == _perPage && fresh.isNotEmpty;
        _isLoadingMore = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _refreshFirstPageFromCache() async {
    try {
      final articles = await _fetchArticles(page: 1);
      if (!mounted || articles.isEmpty) return;
      setState(() {
        _page = 1;
        _articles
          ..clear()
          ..addAll(articles);
        _hasMore = articles.length == _perPage;
        _isLoading = false;
        _error = null;
      });
    } on Object {
      // Keep current category content if the refreshed cache cannot be read.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const WPScaffold(child: WPSkeletonList(itemCount: 6));
    }
    if (_error != null) {
      return WPScaffold(
        child: WPErrorState(
          title: '${category.name} could not load',
          message: _error!,
          onRetry: _loadFirstPage,
        ),
      );
    }
    if (_articles.isEmpty) {
      return WPScaffold(
        child: WPEmptyState(
          icon: Icons.article_outlined,
          title: 'No ${category.name} news yet',
          message: 'Fresh stories in this category will appear here.',
        ),
      );
    }
    return WPScaffold(
      child: RefreshIndicator(
        onRefresh: _loadFirstPage,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          children: [
            Text(
              category.name,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            for (final article in _articles)
              _CategoryArticleCard(article: article),
            if (_isLoadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: WPBrandLoader(size: 64, compact: true),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryArticleCard extends ConsumerStatefulWidget {
  const _CategoryArticleCard({required this.article});

  final Article article;

  @override
  ConsumerState<_CategoryArticleCard> createState() =>
      _CategoryArticleCardState();
}

class _CategoryArticleCardState extends ConsumerState<_CategoryArticleCard> {
  var _isBookmarked = false;

  Article get article => widget.article;

  @override
  void initState() {
    super.initState();
    _loadBookmark();
  }

  @override
  void didUpdateWidget(covariant _CategoryArticleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.article.id != widget.article.id) {
      _loadBookmark();
    }
  }

  Future<void> _loadBookmark() async {
    final isBookmarked =
        await ref.read(bookmarkRepositoryProvider).isBookmarked(article.id);
    if (mounted) {
      setState(() => _isBookmarked = isBookmarked);
    }
  }

  Future<void> _toggleBookmark() async {
    final next = !_isBookmarked;
    setState(() => _isBookmarked = next);
    await ref
        .read(bookmarkRepositoryProvider)
        .setArticleBookmark(article.id, next);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/article/${article.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WPImage(
              url: article.imageUrl,
              height: 172,
              width: double.infinity,
              borderRadius: 0,
            ),
            Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(height: 1.12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article.excerpt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted, height: 1.3),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined,
                          size: 17, color: AppColors.muted),
                      const SizedBox(width: 5),
                      Text(
                        DateFormat('d MMM yyyy').format(article.date),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Bookmark',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(_isBookmarked
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded),
                        color: AppColors.copper,
                        onPressed: _toggleBookmark,
                      ),
                      IconButton(
                        tooltip: 'Share',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.share_rounded),
                        color: AppColors.copper,
                        onPressed: () =>
                            Share.share('${article.title}\n${article.url}'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  Timer? _debounce;
  var _query = '';
  var _isLoading = false;
  String? _error;
  List<Article> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    setState(() => _query = value);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final query = value.trim();
      if (query.isEmpty) {
        if (mounted) {
          setState(() {
            _results = const [];
            _isLoading = false;
            _error = null;
          });
        }
        return;
      }
      setState(() {
        _isLoading = true;
        _error = null;
      });
      try {
        final repository = ref.read(contentRepositoryProvider);
        final results = await repository.searchArticles(query);
        if (mounted) {
          setState(() {
            _results = results;
            _isLoading = false;
          });
        }
      } on Object {
        if (mounted) {
          setState(() {
            _results = const [];
            _error = 'Search could not load. Please try again.';
            _isLoading = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WPScaffold(
      showBack: true,
      title: 'Search',
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          TextField(
            autofocus: true,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search news, topics...',
              prefixIcon: const Icon(Icons.search_rounded),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          if (_query.trim().isEmpty) ...[
            const WPSectionHeader(title: 'Recent Searches'),
            for (final term in [
              'MDF',
              'Sustainability',
              'Plywood',
              'Furniture',
              'IndiaWood 2025'
            ])
              ListTile(
                  leading: const Icon(Icons.history_rounded),
                  title: Text(term)),
          ] else ...[
            const WPSectionHeader(title: 'Results'),
            if (_isLoading)
              const SizedBox(
                height: 260,
                child: WPBrandLoader(size: 112, compact: true),
              )
            else if (_error != null)
              WPErrorState(
                title: 'Search failed',
                message: _error!,
                onRetry: () => _onSearchChanged(_query),
              )
            else if (_results.isEmpty)
              const WPEmptyState(
                icon: Icons.search_off_rounded,
                title: 'No results found',
                message: 'Try another topic, category, company, or keyword.',
              ),
            for (final article in _results) WPCompactNewsCard(article: article),
          ],
        ],
      ),
    );
  }
}

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarkRepository = ref.watch(bookmarkRepositoryProvider);
    final contentRepository = ref.watch(contentRepositoryProvider);
    return WPScaffold(
      showBack: true,
      title: 'Bookmarks',
      child: FutureBuilder(
        future: bookmarkRepository.articleIds(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const WPSkeletonList(itemCount: 4);
          }
          if (snapshot.hasError) {
            return const WPErrorState(
              title: 'Bookmarks could not load',
              message: 'Please reopen Bookmarks and try again.',
            );
          }
          final ids = snapshot.data ?? <int>{};
          if (ids.isEmpty) {
            return const WPEmptyState(
              icon: Icons.bookmark_border_rounded,
              title: 'No bookmarks yet',
              message:
                  'Saved articles, videos, and magazines will appear here.',
            );
          }
          return FutureBuilder(
            future: Future.wait(ids.map(contentRepository.articleById)),
            builder: (context, articlesSnapshot) {
              final articles = articlesSnapshot.data ?? const <Article>[];
              if (articlesSnapshot.connectionState != ConnectionState.done) {
                return const WPSkeletonList(itemCount: 4);
              }
              if (articlesSnapshot.hasError) {
                return const WPErrorState(
                  title: 'Saved articles could not load',
                  message: 'Some saved articles may no longer be available.',
                );
              }
              if (articles.isEmpty) {
                return const WPEmptyState(
                  icon: Icons.bookmark_remove_outlined,
                  title: 'No saved articles found',
                  message: 'Try saving another article from the news feed.',
                );
              }
              return ListView(
                children: [
                  const WPSectionHeader(title: 'Articles'),
                  for (final article in articles)
                    WPCompactNewsCard(article: article),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class MagazineDetailScreen extends ConsumerWidget {
  const MagazineDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(contentRepositoryProvider);
    return WPScaffold(
      showBack: true,
      child: FutureBuilder(
        future: repository.magazines(),
        builder: (context, snapshot) {
          final issue = _issueById(snapshot.data ?? const [], id);
          if (snapshot.connectionState != ConnectionState.done &&
              issue == null) {
            return const WPSkeletonList(itemCount: 4);
          }
          if (snapshot.hasError || issue == null) {
            return const WPErrorState(
              title: 'Magazine could not load',
              message: 'Please reopen Magazine and try again.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              _MagazineCoverImage(
                url: issue.coverUrl,
                height: 430,
                width: double.infinity,
              ),
              const SizedBox(height: 14),
              Text(issue.title,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(issue.description),
              const SizedBox(height: 6),
              Text(
                DateFormat('MMMM yyyy').format(issue.date),
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              WPPrimaryButton(
                label: 'Read Online',
                onPressed: () => context.push('/magazine/${issue.id}/read'),
              ),
              const SizedBox(height: 10),
              _MagazinePdfActionButton(issue: issue),
            ],
          );
        },
      ),
    );
  }
}

class MagazineReaderScreen extends ConsumerWidget {
  const MagazineReaderScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(contentRepositoryProvider);
    return WPScaffold(
      showBack: true,
      child: FutureBuilder(
        future: repository.magazines(),
        builder: (context, snapshot) {
          final issue = _issueById(snapshot.data ?? const [], id);
          if (snapshot.connectionState != ConnectionState.done &&
              issue == null) {
            return const WPSkeletonList(itemCount: 4);
          }
          if (snapshot.hasError || issue == null) {
            return const WPErrorState(
              title: 'Magazine reader could not load',
              message: 'Please reopen Magazine and try again.',
            );
          }
          if (issue.readUrl.isEmpty) {
            return const WPErrorState(
              title: 'Magazine reader could not load',
              message: 'This issue does not have an online reader link yet.',
            );
          }
          return _MagazineWebView(issue: issue);
        },
      ),
    );
  }
}

class _MagazineWebView extends StatefulWidget {
  const _MagazineWebView({required this.issue});

  final MagazineIssue issue;

  @override
  State<_MagazineWebView> createState() => _MagazineWebViewState();
}

class _MagazineWebViewState extends State<_MagazineWebView> {
  late final WebViewController _controller;
  var _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF1A1A1A))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) => setState(() => _progress = progress),
          onPageFinished: (_) => setState(() => _progress = 100),
        ),
      )
      ..loadRequest(Uri.parse(widget.issue.readUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_progress < 100)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black,
              child: WPBrandLoader(
                size: 156,
                label: _progress <= 0 ? null : 'Loading $_progress%',
              ),
            ),
          ),
      ],
    );
  }
}

MagazineIssue? _issueById(List<MagazineIssue> issues, int id) {
  for (final issue in issues) {
    if (issue.id == id) {
      return issue;
    }
  }
  return issues.isEmpty ? null : issues.first;
}

class LegacyInterviewDetailScreen extends StatefulWidget {
  const LegacyInterviewDetailScreen({super.key, required this.url});

  final String url;

  @override
  State<LegacyInterviewDetailScreen> createState() =>
      _LegacyInterviewDetailScreenState();
}

class _LegacyInterviewDetailScreenState
    extends State<LegacyInterviewDetailScreen> {
  late Future<_LegacyInterviewDetail> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = _fetchDetail();
  }

  Future<_LegacyInterviewDetail> _fetchDetail() async {
    if (widget.url.trim().isEmpty) {
      throw StateError('Missing interview URL.');
    }
    final response = await Dio().get<String>(
      widget.url,
      options: Options(
        responseType: ResponseType.plain,
        headers: const {'User-Agent': 'Mozilla/5.0'},
      ),
    );
    return _LegacyInterviewDetail.fromHtml(response.data ?? '', widget.url);
  }

  Future<void> _retry() async {
    setState(() => _detailFuture = _fetchDetail());
    await _detailFuture;
  }

  @override
  Widget build(BuildContext context) {
    return WPScaffold(
      showBack: true,
      child: FutureBuilder<_LegacyInterviewDetail>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const WPSkeletonList(showHero: true, itemCount: 5);
          }
          if (snapshot.hasError || snapshot.data == null) {
            return WPErrorState(
              title: 'Interview could not load',
              message: 'Please check your connection and try again.',
              onRetry: _retry,
            );
          }
          final detail = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _retry,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
              children: [
                if (detail.imageUrl.isNotEmpty) ...[
                  WPImage(
                    url: detail.imageUrl,
                    height: 260,
                    width: double.infinity,
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  detail.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        height: 1.08,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                if (detail.introHtml.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F1EC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: HtmlWidget(detail.introHtml),
                  ),
                ],
                const SizedBox(height: 14),
                HtmlWidget(
                  detail.contentHtml,
                  textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.42,
                        color: AppColors.ink,
                      ),
                  onTapUrl: (url) {
                    _openUrl(url);
                    return true;
                  },
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () =>
                      Share.share('${detail.title}\n${widget.url}'),
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LegacyInterviewDetail {
  const _LegacyInterviewDetail({
    required this.title,
    required this.imageUrl,
    required this.introHtml,
    required this.contentHtml,
  });

  final String title;
  final String imageUrl;
  final String introHtml;
  final String contentHtml;

  static _LegacyInterviewDetail fromHtml(String html, String url) {
    final title = _decodeLegacyHtml(
      _stripLegacyHtml(
        _firstLegacyMatch(
              html,
              r'<div class="interview-page-title">\s*([\s\S]*?)\s*</div>',
            ) ??
            _firstLegacyMatch(
              html,
              r'<meta property="og:title" content="([^"]+)"',
            ) ??
            'Interview',
      ),
    ).replaceAll(' - Wood & Panel Europe', '');
    final imageBlock = _firstLegacyMatch(
          html,
          r'<div class="interview-img">\s*([\s\S]*?)\s*</div>',
        ) ??
        '';
    final imageUrl = _legacyImageUrl(
      _decodeLegacyHtml(
        _firstLegacyMatch(imageBlock, r'data-breeze="([^"]+)"') ??
            _firstLegacyMatch(imageBlock, r'<img[^>]+src="([^"]+)"') ??
            _firstLegacyMatch(
              html,
              r'<meta property="og:image" content="([^"]+)"',
            ) ??
            '',
      ),
    );
    final intro = _firstLegacyMatch(
          html,
          r'<div class="interview-intro">\s*([\s\S]*?)\s*</div>',
        ) ??
        '';
    final content = _firstLegacyMatch(
          html,
          r'<div class="interview-content">\s*([\s\S]*?)\s*</div>',
        ) ??
        _firstLegacyMatch(
          html,
          r'<meta name="description" content="([^"]+)"',
        ) ??
        '';
    final decodedContent = _decodeLegacyHtml(content);
    return _LegacyInterviewDetail(
      title: title,
      imageUrl: imageUrl,
      introHtml: _decodeLegacyHtml(intro),
      contentHtml: decodedContent.isEmpty
          ? '<p>Read the full interview at <a href="$url">$url</a>.</p>'
          : decodedContent,
    );
  }
}

String? _firstLegacyMatch(String value, String pattern) {
  return RegExp(pattern, caseSensitive: false)
      .firstMatch(value)
      ?.group(1)
      ?.trim();
}

String _legacyImageUrl(String value) {
  final cleaned = value.trim();
  if (cleaned.isEmpty || cleaned.startsWith('data:')) {
    return '';
  }
  return cleaned;
}

String _stripLegacyHtml(String value) {
  return value
      .replaceAll(RegExp('<[^>]*>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _decodeLegacyHtml(String value) {
  var decoded = value;
  for (var pass = 0; pass < 2; pass++) {
    decoded = decoded
        .replaceAll('&amp;', '&')
        .replaceAll('&#038;', '&')
        .replaceAll('&#8217;', "'")
        .replaceAll('&#8216;', "'")
        .replaceAll('&rsquo;', "'")
        .replaceAll('&lsquo;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&#8220;', '"')
        .replaceAll('&#8221;', '"')
        .replaceAll('&ldquo;', '"')
        .replaceAll('&rdquo;', '"')
        .replaceAll('&#8211;', '-')
        .replaceAll('&#8212;', '-')
        .replaceAll('&ndash;', '-')
        .replaceAll('&mdash;', '-')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&hellip;', '...')
        .replaceAll('&auml;', 'ä')
        .replaceAll('&Auml;', 'Ä')
        .replaceAll('&eacute;', 'é')
        .replaceAll('&Eacute;', 'É')
        .replaceAll('&iacute;', 'í')
        .replaceAll('&Iacute;', 'Í')
        .replaceAll('&oacute;', 'ó')
        .replaceAll('&Oacute;', 'Ó')
        .replaceAll('&ouml;', 'ö')
        .replaceAll('&Ouml;', 'Ö')
        .replaceAll('&uuml;', 'ü')
        .replaceAll('&Uuml;', 'Ü')
        .replaceAll('&ccedil;', 'ç')
        .replaceAll('&Ccedil;', 'Ç')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }
  return decoded;
}

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(downloadRepositoryProvider);
    final contentRepository = ref.watch(contentRepositoryProvider);
    return WPScaffold(
      showBack: true,
      title: 'Downloads',
      child: FutureBuilder(
        future: Future.wait<Object>([
          repository.files(),
          contentRepository.magazines(),
        ]),
        builder: (context, snapshot) {
          final data = snapshot.data;
          final items = data == null
              ? const <DownloadedFile>[]
              : data[0] as List<DownloadedFile>;
          final issues = data == null
              ? const <MagazineIssue>[]
              : data[1] as List<MagazineIssue>;
          if (snapshot.connectionState != ConnectionState.done) {
            return const WPSkeletonList(itemCount: 4);
          }
          if (items.isEmpty) {
            return const WPEmptyState(
              icon: Icons.download_done_rounded,
              title: 'No downloads yet',
              message:
                  'Downloaded magazine PDFs will appear here after you tap Download PDF.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
            children: [
              Text('Downloads',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 14),
              for (final item in items)
                _DownloadedFileTile(
                  item: item,
                  coverUrl: _coverForDownloadedFile(item, issues),
                ),
            ],
          );
        },
      ),
    );
  }
}

class WallpapersScreen extends StatelessWidget {
  const WallpapersScreen({super.key});

  @override
  Widget build(BuildContext context) => const _WallpaperScreen();
}

class SubscribeScreen extends StatelessWidget {
  const SubscribeScreen({super.key});

  @override
  Widget build(BuildContext context) => _ActionScreen(
      title: 'Subscribe to Wood & Panel Premium',
      icon: Icons.workspace_premium_rounded,
      button: 'Subscribe Now',
      route: '/profile');
}

class PreferencesScreen extends ConsumerWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeControllerProvider) == ThemeMode.dark;
    return WPScaffold(
      showBack: true,
      title: 'Preferences',
      child: ListView(
        children: [
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: isDark,
            onChanged: (value) => ref
                .read(themeModeControllerProvider.notifier)
                .setDarkMode(value),
          ),
          SwitchListTile(
              title: const Text('Notifications'),
              value: true,
              onChanged: (_) {}),
          const ListTile(
              title: Text('Language'),
              subtitle: Text('English'),
              trailing: Icon(Icons.chevron_right_rounded)),
          const ListTile(
              title: Text('Font Size'),
              subtitle: Text('Medium'),
              trailing: Icon(Icons.chevron_right_rounded)),
        ],
      ),
    );
  }
}

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) => const _FormScreen(
        title: 'Contact Us',
        button: 'Send Message',
        mode: _FormMode.contact,
      );
}

class NewsletterScreen extends StatelessWidget {
  const NewsletterScreen({super.key});

  @override
  Widget build(BuildContext context) => const _FormScreen(
        title: 'Subscribe to Our Newsletter',
        button: 'Subscribe',
        mode: _FormMode.newsletter,
      );
}

class GrowWithUsScreen extends StatelessWidget {
  const GrowWithUsScreen({super.key});

  @override
  Widget build(BuildContext context) => _ActionScreen(
        title: 'Partner with Wood & Panel',
        icon: Icons.handshake_rounded,
        button: 'Get In Touch',
        route: '/contact',
        points: const [
          'Advertising opportunities',
          'Event partnerships',
          'Brand collaborations',
          'Digital solutions'
        ],
      );
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => const _AboutScreenContent();
}

class GroupMediaScreen extends StatelessWidget {
  const GroupMediaScreen({super.key});

  @override
  Widget build(BuildContext context) => const _BrandListScreen(
        title: 'Group Media',
        subtitle:
            'Part of a trusted media family covering wood, panels, furniture, and surfaces.',
        items: [
          'Wood & Panel',
          'Ply Reporter',
          'MDF Times',
          'Furniture & Fittings',
          'IndiaWood Magazine'
        ],
      );
}

class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context) => const _BrandListScreen(
        title: 'Our Clients',
        subtitle: 'Partnering with leading brands globally.',
        items: [
          'Greenpanel',
          'CenturyPly',
          'Action TESA',
          'Hettich',
          'Blum',
          'Rehau',
          'MAZ',
          'SCM'
        ],
      );
}

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(contentRepositoryProvider);
    return WPScaffold(
      showBack: true,
      title: 'Events',
      child: FutureBuilder(
        future: repository.events(),
        builder: (context, snapshot) {
          final events = snapshot.data ?? [];
          if (snapshot.connectionState != ConnectionState.done) {
            return const WPSkeletonList(itemCount: 4);
          }
          if (snapshot.hasError) {
            return const WPErrorState(
              title: 'Events could not load',
              message: 'Please check your connection and reopen Events.',
            );
          }
          if (events.isEmpty) {
            return const WPEmptyState(
              icon: Icons.event_busy_rounded,
              title: 'No events yet',
              message: 'Upcoming industry events will appear here.',
            );
          }
          return ListView(
            children: [
              for (final event in events)
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  leading: WPImage(url: event.imageUrl, width: 82, height: 68),
                  title: Text(event.title,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text('${event.date}\n${event.location}'),
                  isThreeLine: true,
                ),
            ],
          );
        },
      ),
    );
  }
}

class InterviewDetailScreen extends StatelessWidget {
  const InterviewDetailScreen({super.key});

  @override
  Widget build(BuildContext context) => _ActionScreen(
      title: 'In Conversation with Rohit Agarwal',
      icon: Icons.record_voice_over_rounded,
      button: 'Read Article',
      route: '/article/4');
}

class _ActionScreen extends StatelessWidget {
  const _ActionScreen({
    required this.title,
    required this.icon,
    required this.button,
    required this.route,
    this.points = const [
      'Read all magazine issues',
      'Access premium articles',
      'Exclusive interviews',
      'Industry reports and data'
    ],
  });

  final String title;
  final IconData icon;
  final String button;
  final String route;
  final List<String> points;

  @override
  Widget build(BuildContext context) {
    return WPScaffold(
      showBack: true,
      title: title,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 54, color: AppColors.copper),
            const SizedBox(height: 18),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            for (final point in points)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.copper, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(point,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700))),
                  ],
                ),
              ),
            const Spacer(),
            WPPrimaryButton(
                label: button, onPressed: () => context.push(route)),
          ],
        ),
      ),
    );
  }
}

class _YouTubeVideoCard extends StatelessWidget {
  const _YouTubeVideoCard({required this.video});

  final YouTubeVideo video;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/video/${video.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                WPImage(
                  url: video.thumbnailUrl,
                  height: 190,
                  width: double.infinity,
                  borderRadius: 0,
                ),
                Positioned.fill(
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.ink.withValues(alpha: .72),
                        shape: BoxShape.circle,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 34),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(height: 1.12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    video.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: AppColors.muted, height: 1.25),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined,
                          size: 17, color: AppColors.muted),
                      const SizedBox(width: 5),
                      Text(
                        DateFormat('d MMM yyyy').format(video.publishedAt),
                        style: const TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Share',
                        icon: const Icon(Icons.share_rounded),
                        color: AppColors.copper,
                        onPressed: () =>
                            Share.share('${video.title}\n${video.url}'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoPlayerScreen extends ConsumerStatefulWidget {
  const VideoPlayerScreen({super.key, required this.videoId});

  final String videoId;

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  late final YoutubePlayerController _controller;
  late Future<YouTubeVideo?> _videoFuture;
  var _showFullDescription = false;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        playsInline: true,
        enableCaption: true,
        strictRelatedVideos: true,
      ),
    );
    _videoFuture = _fetchVideo();
  }

  Future<YouTubeVideo?> _fetchVideo() async {
    final videos =
        await ref.read(youtubeVideoRepositoryProvider).latestVideos();
    for (final video in videos) {
      if (video.id == widget.videoId) {
        return video;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoUrl = 'https://www.youtube.com/watch?v=${widget.videoId}';
    return WPScaffold(
      showBack: true,
      title: 'Video',
      child: FutureBuilder<YouTubeVideo?>(
        future: _videoFuture,
        builder: (context, snapshot) {
          final video = snapshot.data;
          final description = video?.description.trim() ?? '';
          final hasDescription = description.isNotEmpty;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: YoutubePlayer(
                  controller: _controller,
                  aspectRatio: 16 / 9,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                video?.title ?? 'Wood & Panel video',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 24,
                      height: 1.08,
                    ),
              ),
              const SizedBox(height: 8),
              if (video != null) ...[
                Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined,
                        size: 17, color: AppColors.muted),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('d MMM yyyy').format(video.publishedAt),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Share',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.share_rounded),
                      color: AppColors.copper,
                      onPressed: () => Share.share(
                        '${video.title}\n${video.url}',
                      ),
                    ),
                  ],
                ),
                if (hasDescription) ...[
                  const SizedBox(height: 10),
                  _LinkifiedDescription(
                    text: description,
                    expanded: _showFullDescription,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.copper,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => setState(
                        () => _showFullDescription = !_showFullDescription,
                      ),
                      child: Text(
                        _showFullDescription
                            ? 'View less'
                            : 'View full description',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
              ],
              WPPrimaryButton(
                label: 'Open in YouTube',
                onPressed: () => _openUrl(video?.url ?? videoUrl),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LinkifiedDescription extends StatefulWidget {
  const _LinkifiedDescription({
    required this.text,
    required this.expanded,
  });

  final String text;
  final bool expanded;

  @override
  State<_LinkifiedDescription> createState() => _LinkifiedDescriptionState();
}

class _LinkifiedDescriptionState extends State<_LinkifiedDescription> {
  final List<TapGestureRecognizer> _recognizers = [];

  static final RegExp _urlPattern = RegExp(
    r'((https?:\/\/|www\.)[^\s<]+)',
    caseSensitive: false,
  );

  @override
  void dispose() {
    _clearRecognizers();
    super.dispose();
  }

  void _clearRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();
    final normalStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: AppColors.muted,
          height: 1.3,
        );
    const linkStyle = TextStyle(
      color: AppColors.copper,
      fontWeight: FontWeight.w800,
      decoration: TextDecoration.underline,
    );
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in _urlPattern.allMatches(widget.text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, match.start)));
      }
      final rawUrl = match.group(0)!;
      final url = rawUrl.startsWith('http') ? rawUrl : 'https://$rawUrl';
      final recognizer = TapGestureRecognizer()..onTap = () => _openUrl(url);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: rawUrl,
          style: linkStyle,
          recognizer: recognizer,
        ),
      );
      cursor = match.end;
    }

    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(style: normalStyle, children: spans),
      maxLines: widget.expanded ? null : 3,
      overflow: widget.expanded ? TextOverflow.visible : TextOverflow.ellipsis,
    );
  }
}

Future<void> _openUrl(String url) async {
  final uri = Uri.parse(url);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> _downloadMagazinePdf(
  BuildContext context,
  MagazineIssue issue,
) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text('Downloading ${issue.title}...'),
      duration: const Duration(seconds: 2),
    ),
  );
  try {
    final repository =
        ProviderScope.containerOf(context).read(downloadRepositoryProvider);
    await repository.downloadPdf(
      title: 'Wood & Panel ${issue.title}',
      url: issue.pdfUrl,
      coverUrl: issue.coverUrl,
    );
    if (!context.mounted) {
      return;
    }
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('PDF downloaded'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Downloads',
          onPressed: () => context.push('/downloads'),
        ),
      ),
    );
  } on Object {
    if (!context.mounted) {
      return;
    }
    messenger.clearSnackBars();
    messenger.showSnackBar(
      const SnackBar(content: Text('Download failed. Please try again.')),
    );
  }
}

void _openDownloadedPdf(BuildContext context, DownloadedFile item) {
  context.push('/downloaded-pdf', extra: item);
}

void _openInterview(BuildContext context, Article article) {
  if (article.id > 0) {
    context.push('/article/${article.id}');
    return;
  }
  context.push(
    Uri(
      path: '/legacy-interview',
      queryParameters: {'url': article.url},
    ).toString(),
  );
}

class _DownloadedFileTile extends StatelessWidget {
  const _DownloadedFileTile({required this.item, required this.coverUrl});

  final DownloadedFile item;
  final String coverUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: InkWell(
        onTap: () => _openDownloadedPdf(context, item),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: coverUrl.isEmpty
                    ? Container(
                        width: 54,
                        height: 64,
                        color: const Color(0xFFF7F1EC),
                        child: const Icon(Icons.picture_as_pdf_rounded,
                            color: AppColors.copper),
                      )
                    : WPImage(
                        url: coverUrl,
                        width: 54,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${_formatFileSize(item.size)} - ${DateFormat('d MMM yyyy').format(item.downloadedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'View',
                constraints: const BoxConstraints.tightFor(
                  width: 38,
                  height: 38,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.visibility_outlined,
                    color: AppColors.copper),
                onPressed: () => _openDownloadedPdf(context, item),
              ),
              IconButton(
                tooltip: 'Share',
                constraints: const BoxConstraints.tightFor(
                  width: 38,
                  height: 38,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.share_rounded, color: AppColors.copper),
                onPressed: () => Share.shareXFiles([XFile(item.path)]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _coverForDownloadedFile(
  DownloadedFile item,
  List<MagazineIssue> issues,
) {
  if (item.coverUrl.isNotEmpty) {
    return item.coverUrl;
  }
  for (final issue in issues) {
    if (issue.pdfUrl == item.url || item.title.contains(issue.title)) {
      return issue.coverUrl;
    }
  }
  return '';
}

class DownloadedPdfScreen extends StatelessWidget {
  const DownloadedPdfScreen({super.key, required this.file});

  final DownloadedFile file;

  @override
  Widget build(BuildContext context) {
    return WPScaffold(
      showBack: true,
      showBottomNav: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    file.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Share',
                  icon:
                      const Icon(Icons.share_rounded, color: AppColors.copper),
                  onPressed: () => Share.shareXFiles([XFile(file.path)]),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: PDFView(
              filePath: file.path,
              enableSwipe: true,
              swipeHorizontal: false,
              autoSpacing: false,
              pageFling: false,
              pageSnap: false,
              fitPolicy: FitPolicy.WIDTH,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatFileSize(int bytes) {
  if (bytes <= 0) {
    return 'Downloaded';
  }
  final mb = bytes / (1024 * 1024);
  if (mb >= 1) {
    return '${mb.toStringAsFixed(1)} MB';
  }
  final kb = bytes / 1024;
  return '${kb.toStringAsFixed(0)} KB';
}

class _WallpaperScreen extends StatelessWidget {
  const _WallpaperScreen();

  static const _images = [
    'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=900&q=80',
    'https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?auto=format&fit=crop&w=900&q=80',
    'https://images.unsplash.com/photo-1600210492493-0946911123ea?auto=format&fit=crop&w=900&q=80',
    'https://images.unsplash.com/photo-1516972810927-80185027ca84?auto=format&fit=crop&w=900&q=80',
    'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?auto=format&fit=crop&w=900&q=80',
    'https://images.unsplash.com/photo-1600566753190-17f0baa2a6c3?auto=format&fit=crop&w=900&q=80',
  ];

  @override
  Widget build(BuildContext context) {
    return WPScaffold(
      showBack: true,
      title: 'Wallpapers',
      child: GridView.builder(
        padding: const EdgeInsets.all(18),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: .72,
        ),
        itemCount: _images.length,
        itemBuilder: (context, index) => Stack(
          fit: StackFit.expand,
          children: [
            WPImage(url: _images[index]),
            Positioned(
              right: 8,
              bottom: 8,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: IconButton(
                  tooltip: 'Download wallpaper',
                  icon: const Icon(Icons.download_rounded,
                      color: AppColors.copper),
                  onPressed: () {},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutScreenContent extends StatelessWidget {
  const _AboutScreenContent();

  @override
  Widget build(BuildContext context) {
    return WPScaffold(
      showBack: true,
      title: 'About Us',
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const WPImage(
            url:
                'https://images.unsplash.com/photo-1600607688969-a5bfcd646154?auto=format&fit=crop&w=1200&q=80',
            height: 180,
            width: double.infinity,
          ),
          const SizedBox(height: 16),
          Text('Wood & Panel',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          const Text(
            'A leading media platform for the global wood, panel, furniture and surface industry, bringing news, insights and opportunities to professionals.',
          ),
          const SizedBox(height: 18),
          Row(
            children: const [
              Expanded(child: _StatTile(value: '15+', label: 'Years')),
              SizedBox(width: 10),
              Expanded(child: _StatTile(value: '50K+', label: 'Readers')),
              SizedBox(width: 10),
              Expanded(child: _StatTile(value: '10K+', label: 'Articles')),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F1EC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            Text(label, style: const TextStyle(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _BrandListScreen extends StatelessWidget {
  const _BrandListScreen({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return WPScaffold(
      showBack: true,
      title: title,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(subtitle),
          const SizedBox(height: 16),
          for (final item in items)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: AppColors.green),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(item,
                          style: const TextStyle(fontWeight: FontWeight.w900))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

enum _FormMode { contact, newsletter }

class _FormScreen extends ConsumerStatefulWidget {
  const _FormScreen({
    required this.title,
    required this.button,
    required this.mode,
  });

  final String title;
  final String button;
  final _FormMode mode;

  @override
  ConsumerState<_FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends ConsumerState<_FormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  var _isSending = false;
  String? _status;
  bool _isError = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSending = true;
      _status = null;
      _isError = false;
    });

    try {
      final api = ref.read(appApiRepositoryProvider);
      if (widget.mode == _FormMode.newsletter) {
        await api.subscribeNewsletter(
          name: _name.text.trim(),
          email: _email.text.trim(),
        );
      } else {
        await api.sendContactMessage(
          name: _name.text.trim(),
          email: _email.text.trim(),
          subject: _subject.text.trim(),
          message: _message.text.trim(),
        );
      }
      if (mounted) {
        setState(() {
          _status = widget.mode == _FormMode.newsletter
              ? 'Subscription saved. Please check your inbox for future updates.'
              : 'Message sent. The Wood & Panel team will review it shortly.';
          _isSending = false;
        });
        _subject.clear();
        _message.clear();
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _status = error.toString().replaceFirst('ApiException: ', '');
          _isError = true;
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNewsletter = widget.mode == _FormMode.newsletter;
    return WPScaffold(
      showBack: true,
      title: widget.title,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(widget.title,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 18),
            TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: isNewsletter ? null : _required),
            const SizedBox(height: 10),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              validator: _emailValidator,
            ),
            if (!isNewsletter) ...[
              const SizedBox(height: 10),
              TextFormField(
                  controller: _subject,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  validator: _required),
              const SizedBox(height: 10),
              TextFormField(
                  controller: _message,
                  decoration: const InputDecoration(labelText: 'Message'),
                  minLines: 4,
                  maxLines: 5,
                  validator: _required),
            ],
            const SizedBox(height: 18),
            if (_isSending)
              const WPBrandLoader(size: 70, compact: true)
            else
              WPPrimaryButton(label: widget.button, onPressed: _submit),
            if (_status != null)
              Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  _status!,
                  style: TextStyle(
                      color: _isError ? AppColors.error : AppColors.success),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Required' : null;

  String? _emailValidator(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Required';
    }
    if (!email.contains('@') || !email.contains('.')) {
      return 'Enter a valid email';
    }
    return null;
  }
}
