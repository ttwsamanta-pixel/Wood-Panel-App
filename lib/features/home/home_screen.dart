import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/content_models.dart';
import '../../data/models/news_category.dart';
import '../../data/repositories/app_api_repository.dart';
import '../../data/repositories/cache_refresh_bus.dart';
import '../../data/repositories/content_providers.dart';
import '../../data/repositories/youtube_video_repository.dart';
import '../../widgets/wp_components.dart';
import '../../widgets/wp_scaffold.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late Future<_HomeData> _homeFuture;
  StreamSubscription<CacheRefreshType>? _cacheRefreshSubscription;

  @override
  void initState() {
    super.initState();
    _homeFuture = _fetchHomeData();
    _cacheRefreshSubscription = CacheRefreshBus.stream.listen((type) {
      if (!mounted) return;
      setState(() => _homeFuture = _fetchHomeData());
    });
  }

  @override
  void dispose() {
    _cacheRefreshSubscription?.cancel();
    super.dispose();
  }

  Future<_HomeData> _fetchHomeData() async {
    final contentRepository = ref.read(contentRepositoryProvider);
    final videoRepository = ref.read(youtubeVideoRepositoryProvider);
    final articlesFuture = contentRepository.latestArticles();
    final videosFuture =
        videoRepository.latestVideos().catchError((_) => <YouTubeVideo>[]);
    final magazinesFuture =
        contentRepository.magazines().catchError((_) => <MagazineIssue>[]);
    final eventsFuture =
        contentRepository.events().catchError((_) => <AppEvent>[]);
    final results = await Future.wait<dynamic>([
      articlesFuture,
      videosFuture,
      magazinesFuture,
      eventsFuture,
      Future<void>.delayed(const Duration(milliseconds: 900)),
    ]);
    return _HomeData(
      articles: results[0] as List<Article>,
      videos: results[1] as List<YouTubeVideo>,
      magazines: results[2] as List<MagazineIssue>,
      events: results[3] as List<AppEvent>,
    );
  }

  Future<void> _reloadArticles() async {
    setState(() => _homeFuture = _fetchHomeData());
    await _homeFuture;
  }

  @override
  Widget build(BuildContext context) {
    return WPScaffold(
      child: FutureBuilder<_HomeData>(
        future: _homeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const WPPageLoader();
          }
          if (snapshot.hasError) {
            return WPErrorState(
              title: 'News could not load',
              message: 'Please check your connection and try again.',
              onRetry: () => _reloadArticles(),
            );
          }

          final homeData = snapshot.data ?? _HomeData.empty;
          if (homeData.articles.isEmpty) {
            return const WPEmptyState(
              icon: Icons.article_outlined,
              title: 'No articles yet',
              message: 'Latest Wood And Panel stories will appear here.',
            );
          }

          return RefreshIndicator(
            onRefresh: _reloadArticles,
            child: _HomeContent(
              data: homeData,
            ),
          );
        },
      ),
    );
  }
}

class _HomeData {
  const _HomeData({
    required this.articles,
    required this.videos,
    required this.magazines,
    required this.events,
  });

  static const empty = _HomeData(
    articles: <Article>[],
    videos: <YouTubeVideo>[],
    magazines: <MagazineIssue>[],
    events: <AppEvent>[],
  );

  final List<Article> articles;
  final List<YouTubeVideo> videos;
  final List<MagazineIssue> magazines;
  final List<AppEvent> events;
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.data});

  final _HomeData data;

  @override
  Widget build(BuildContext context) {
    final articles = data.articles;
    final newsletterCoverUrl =
        data.magazines.isNotEmpty ? data.magazines.first.coverUrl : '';
    return ListView(
      children: [
        WPHeroNewsCard(article: articles.first),
        WPSectionHeader(
          title: 'Latest News',
          actionLabel: 'See All',
          onAction: () => context.go('/feed'),
        ),
        for (final article in articles.skip(1).take(4))
          _LatestNewsRow(article: article),
        const WPSectionHeader(title: 'Trending'),
        SizedBox(
          height: 258,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: articles.length,
            itemBuilder: (context, index) =>
                _TrendingCard(article: articles[index]),
          ),
        ),
        const WPSectionHeader(title: 'News Categories'),
        SizedBox(
          height: 112,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: NewsCategory.all.length,
            itemBuilder: (context, index) =>
                _CategoryTile(category: NewsCategory.all[index]),
          ),
        ),
        WPSectionHeader(
          title: 'Videos',
          actionLabel: 'See All',
          onAction: () => context.push('/videos'),
        ),
        _HomeVideoCarousel(videos: data.videos),
        WPSectionHeader(
          title: 'Magazine Highlight',
          actionLabel: 'All Issues',
          onAction: () => context.go('/magazine'),
        ),
        _HomeMagazineCarousel(magazines: data.magazines),
        WPSectionHeader(
          title: 'Upcoming Events',
          actionLabel: 'View All',
          onAction: () => context.push('/events'),
        ),
        _HomeEventsCarousel(events: data.events),
        const SizedBox(height: 16),
        _NewsletterCard(
          coverUrl: newsletterCoverUrl,
          onPressed: () => _showNewsletterPopup(context, newsletterCoverUrl),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _LatestNewsRow extends StatelessWidget {
  const _LatestNewsRow({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      leading: WPImage(url: article.imageUrl, width: 82, height: 68),
      title: Text(
        article.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w900, height: 1.15),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          DateFormat('d MMM yyyy').format(article.date),
          style: const TextStyle(color: AppColors.muted),
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.push('/article/${article.id}'),
    );
  }
}

class _TrendingCard extends StatelessWidget {
  const _TrendingCard({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push('/article/${article.id}'),
      child: Container(
        width: 238,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                WPImage(
                  url: article.imageUrl,
                  height: 126,
                  width: double.infinity,
                  borderRadius: 8,
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: WPTag(article.category),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              article.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900, height: 1.16),
            ),
            const Spacer(),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 14, color: AppColors.muted),
                const SizedBox(width: 5),
                Text(
                  DateFormat('d MMM yyyy').format(article.date),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.schedule_rounded,
                    size: 14, color: AppColors.muted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${article.readingMinutes} min',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Share',
                  onPressed: () =>
                      Share.share('${article.title}\n${article.url}'),
                  icon: const Icon(Icons.share_rounded,
                      color: AppColors.copper, size: 19),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeVideoCarousel extends StatelessWidget {
  const _HomeVideoCarousel({required this.videos});

  final List<YouTubeVideo> videos;

  @override
  Widget build(BuildContext context) {
    final visibleVideos = videos.take(6).toList();
    if (visibleVideos.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 18),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F1EC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            const Icon(Icons.play_circle_fill_rounded,
                color: AppColors.copper, size: 34),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Latest YouTube videos will appear here.',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/videos'),
              child: const Text('Open'),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 226,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: visibleVideos.length,
        itemBuilder: (context, index) =>
            _HomeVideoCard(video: visibleVideos[index]),
      ),
    );
  }
}

class _HomeVideoCard extends StatelessWidget {
  const _HomeVideoCard({required this.video});

  final YouTubeVideo video;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push('/video/${video.id}'),
      child: Container(
        width: 224,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                WPImage(
                  url: video.thumbnailUrl,
                  height: 116,
                  width: double.infinity,
                  borderRadius: 8,
                ),
                Positioned.fill(
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.ink.withValues(alpha: .66),
                        shape: BoxShape.circle,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(9),
                        child: Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              video.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900, height: 1.12),
            ),
            const SizedBox(height: 5),
            Text(
              DateFormat('d MMM yyyy').format(video.publishedAt),
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeMagazineCarousel extends StatelessWidget {
  const _HomeMagazineCarousel({required this.magazines});

  final List<MagazineIssue> magazines;

  @override
  Widget build(BuildContext context) {
    final issues = recentYearIssues(magazines);
    if (issues.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 18),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F1EC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            const Icon(Icons.menu_book_rounded,
                color: AppColors.copper, size: 32),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Magazine issues will appear here.',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/magazine'),
              child: const Text('Open'),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 398,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: issues.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => Align(
          alignment: Alignment.topCenter,
          child: _HomeMagazineCard(issue: issues[index]),
        ),
      ),
    );
  }

  static List<MagazineIssue> recentYearIssues(List<MagazineIssue> issues) {
    if (issues.isEmpty) {
      return const [];
    }
    final currentYear = DateTime.now().year;
    final currentYearIssues =
        issues.where((issue) => issue.date.year == currentYear).toList();
    if (currentYearIssues.isNotEmpty) {
      return currentYearIssues;
    }
    return issues.take(8).toList();
  }
}

class _HomeMagazineCard extends StatelessWidget {
  const _HomeMagazineCard({required this.issue});

  final MagazineIssue issue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 252,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => context.push('/magazine/${issue.id}'),
            child: WPImage(
              url: issue.coverUrl,
              width: double.infinity,
              height: 270,
              fit: BoxFit.cover,
              borderRadius: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            issue.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 18,
                  height: 1.04,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            issue.description.isEmpty
                ? 'Wood and panel industry insights'
                : issue.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.muted,
              height: 1.14,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const _HomeMagazineIssueMeta(
                  icon: Icons.menu_book_rounded, label: 'Vol. 18'),
              const SizedBox(width: 12),
              _HomeMagazineIssueMeta(
                icon: Icons.article_outlined,
                label: 'Issue ${issue.date.month}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeMagazineIssueMeta extends StatelessWidget {
  const _HomeMagazineIssueMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.muted),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeEventsCarousel extends StatelessWidget {
  const _HomeEventsCarousel({required this.events});

  final List<AppEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return _FeatureBand(
        icon: Icons.event_busy_rounded,
        title: 'No website events found',
        subtitle: 'Events from Wood & Panel will appear here when listed.',
        button: 'Open Events',
        onPressed: () => context.push('/events'),
      );
    }
    return SizedBox(
      height: 142,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: events.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _HomeEventCard(
          event: events[index],
          onTap: () => context.push('/events'),
        ),
      ),
    );
  }
}

class _HomeEventCard extends StatelessWidget {
  const _HomeEventCard({required this.event, required this.onTap});

  final AppEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: MediaQuery.sizeOf(context).width * .78,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              flex: 43,
              child: ColoredBox(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: WPImage(
                    url: event.imageUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.contain,
                    borderRadius: 0,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 57,
              child: Container(
                height: double.infinity,
                color: AppColors.green,
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _compactEventDate(event.date),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .78),
                        fontSize: 14,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Venue: ${event.location}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .82),
                        fontSize: 13,
                        height: 1.18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _compactEventDate(String rawDate) {
    final normalized = rawDate.replaceAll(RegExp(r'\s+'), ' ').trim();
    final year = RegExp(r'\b(19|20)\d{2}\b').firstMatch(normalized)?.group(0);
    final monthMatches = RegExp(
      r'\b(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:t(?:ember)?)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\b',
      caseSensitive: false,
    ).allMatches(normalized).toList();
    final days = RegExp(r'\b\d{1,2}\b')
        .allMatches(normalized)
        .map((match) => match.group(0) ?? '')
        .where((value) => value.isNotEmpty)
        .toList();
    if (monthMatches.isEmpty || days.isEmpty) {
      return normalized;
    }
    final firstMonth = _shortMonth(monthMatches.first.group(0) ?? '');
    final lastMonth = _shortMonth(monthMatches.last.group(0) ?? firstMonth);
    final firstDay = days.first;
    final lastDay = days.length > 1 ? days.last : '';
    final dateText = lastDay.isEmpty
        ? '$firstMonth $firstDay'
        : firstMonth == lastMonth
            ? '$firstMonth $firstDay - $lastDay'
            : '$firstMonth $firstDay - $lastMonth $lastDay';
    return year == null ? dateText : '$dateText, $year';
  }

  String _shortMonth(String month) {
    final lower = month.toLowerCase();
    if (lower.startsWith('jan')) return 'Jan';
    if (lower.startsWith('feb')) return 'Feb';
    if (lower.startsWith('mar')) return 'Mar';
    if (lower.startsWith('apr')) return 'Apr';
    if (lower.startsWith('may')) return 'May';
    if (lower.startsWith('jun')) return 'Jun';
    if (lower.startsWith('jul')) return 'Jul';
    if (lower.startsWith('aug')) return 'Aug';
    if (lower.startsWith('sep')) return 'Sep';
    if (lower.startsWith('oct')) return 'Oct';
    if (lower.startsWith('nov')) return 'Nov';
    if (lower.startsWith('dec')) return 'Dec';
    return month;
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final NewsCategory category;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push('/category/${category.id}'),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(13),
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
              style: const TextStyle(fontWeight: FontWeight.w800, height: 1.1),
            ),
          ],
        ),
      ),
    );
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

class _FeatureBand extends StatelessWidget {
  const _FeatureBand({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.button,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String button;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, height: 1.25),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.green,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: onPressed,
                    child: Text(button),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsletterCard extends StatelessWidget {
  const _NewsletterCard({
    required this.coverUrl,
    required this.onPressed,
  });

  final String coverUrl;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 184,
        margin: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7EC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE7D6C7)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              flex: 57,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mail_outline_rounded,
                            color: AppColors.copper, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'NEWSLETTER',
                          style: TextStyle(
                            color: AppColors.copper,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      text: const TextSpan(
                        style: TextStyle(
                          color: AppColors.green,
                          fontSize: 17,
                          height: 1.04,
                          fontWeight: FontWeight.w900,
                        ),
                        children: [
                          TextSpan(text: 'Stay Ahead\nin the Wood &\nPanel '),
                          TextSpan(
                            text: 'Industry',
                            style: TextStyle(color: AppColors.copper),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Get the latest news, events, magazine highlights and industry insights.',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF55504A),
                        fontSize: 10,
                        height: 1.16,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 34,
                      width: 144,
                      child: FilledButton.icon(
                        onPressed: onPressed,
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text(
                          'Subscribe Now',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.copper,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 43,
              child: _NewsletterArtwork(
                coverUrl: coverUrl,
                phoneWidth: 78,
                phoneHeight: 132,
                circleSize: 142,
                mailSize: 54,
                leafSize: 42,
                phoneRight: 20,
                phoneTop: 20,
                mailLeft: 4,
                mailTop: 60,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsletterPhonePreview extends StatelessWidget {
  const _NewsletterPhonePreview({
    required this.coverUrl,
    required this.width,
    required this.height,
  });

  final String coverUrl;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFF17130F),
        borderRadius: BorderRadius.circular(width * .16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * .12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            coverUrl.isEmpty
                ? const ColoredBox(color: AppColors.green)
                : WPImage(
                    url: coverUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
            Positioned(
              left: width * .28,
              right: width * .28,
              top: 5,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Text(
                'WOOD & PANEL',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: width * .1,
                  fontWeight: FontWeight.w900,
                  shadows: const [
                    Shadow(color: Colors.black54, blurRadius: 6),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsletterArtwork extends StatelessWidget {
  const _NewsletterArtwork({
    required this.coverUrl,
    required this.phoneWidth,
    required this.phoneHeight,
    required this.circleSize,
    required this.mailSize,
    required this.leafSize,
    required this.phoneRight,
    required this.phoneTop,
    required this.mailLeft,
    required this.mailTop,
  });

  final String coverUrl;
  final double phoneWidth;
  final double phoneHeight;
  final double circleSize;
  final double mailSize;
  final double leafSize;
  final double phoneRight;
  final double phoneTop;
  final double mailLeft;
  final double mailTop;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          right: -circleSize * .22,
          top: -circleSize * .18,
          child: Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE7C297).withValues(alpha: .55),
            ),
          ),
        ),
        Positioned(
          right: phoneRight,
          top: phoneTop,
          child: Transform.rotate(
            angle: .16,
            child: _NewsletterPhonePreview(
              coverUrl: coverUrl,
              width: phoneWidth,
              height: phoneHeight,
            ),
          ),
        ),
        Positioned(
          left: mailLeft,
          top: mailTop,
          child: Container(
            width: mailSize,
            height: mailSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: .58),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x16000000),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Icon(
              Icons.mail_outline_rounded,
              color: Colors.white,
              size: mailSize * .52,
            ),
          ),
        ),
        Positioned(
          right: -leafSize * .2,
          bottom: -leafSize * .25,
          child: Transform.rotate(
            angle: -.5,
            child: Container(
              width: leafSize,
              height: leafSize * 1.35,
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: .82),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(leafSize),
                  topRight: Radius.circular(leafSize * .35),
                  bottomLeft: Radius.circular(leafSize * .35),
                  bottomRight: Radius.circular(leafSize),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _showNewsletterPopup(BuildContext context, String coverUrl) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .72),
    builder: (_) => _NewsletterPopup(coverUrl: coverUrl),
  );
}

class _NewsletterPopup extends ConsumerStatefulWidget {
  const _NewsletterPopup({required this.coverUrl});

  final String coverUrl;

  @override
  ConsumerState<_NewsletterPopup> createState() => _NewsletterPopupState();
}

class _NewsletterPopupState extends ConsumerState<_NewsletterPopup> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _country = TextEditingController(text: 'India');
  var _isSending = false;
  String? _status;
  bool _isError = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _country.dispose();
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
      await ref.read(appApiRepositoryProvider).subscribeNewsletter(
            name: _name.text.trim(),
            email: _email.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _status = 'Thank you. You are subscribed.';
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _isError = true;
        _status = error.toString().replaceFirst('ApiException: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7EC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 166,
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned(
                          left: 0,
                          top: 22,
                          child: RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                fontSize: 28,
                                height: 1.04,
                                color: AppColors.green,
                                fontWeight: FontWeight.w900,
                              ),
                              children: [
                                TextSpan(text: 'Join Our\n'),
                                TextSpan(
                                  text: 'Newsletter',
                                  style: TextStyle(color: AppColors.copper),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 0,
                          right: 120,
                          top: 102,
                          child: Text(
                            'Get the latest news, events, magazine highlights and industry insights.',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF56504A),
                              fontSize: 12,
                              height: 1.25,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: ClipRect(
                            child: SizedBox(
                              width: 126,
                              height: 132,
                              child: _NewsletterArtwork(
                                coverUrl: widget.coverUrl,
                                phoneWidth: 68,
                                phoneHeight: 116,
                                circleSize: 112,
                                mailSize: 52,
                                leafSize: 32,
                                phoneRight: 14,
                                phoneTop: 10,
                                mailLeft: 2,
                                mailTop: 56,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _NewsletterTextField(
                    controller: _name,
                    icon: Icons.person_outline_rounded,
                    hint: 'Full Name',
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  _NewsletterTextField(
                    controller: _email,
                    icon: Icons.mail_outline_rounded,
                    hint: 'Email Address',
                    keyboardType: TextInputType.emailAddress,
                    validator: _emailValidator,
                  ),
                  const SizedBox(height: 12),
                  _NewsletterTextField(
                    controller: _country,
                    icon: Icons.language_rounded,
                    hint: 'Country',
                    validator: _required,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _isSending ? null : _submit,
                      iconAlignment: IconAlignment.end,
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward_rounded),
                      label: Text(_isSending ? 'Submitting' : 'Submit'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.copper,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  if (_status != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _status!,
                        style: TextStyle(
                          color: _isError ? AppColors.error : AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton.filled(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                minimumSize: const Size(42, 42),
                fixedSize: const Size(42, 42),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  String? _emailValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Required';
    if (!text.contains('@') || !text.contains('.')) {
      return 'Enter a valid email';
    }
    return null;
  }
}

class _NewsletterTextField extends StatelessWidget {
  const _NewsletterTextField({
    required this.controller,
    required this.icon,
    required this.hint,
    required this.validator,
    this.keyboardType,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: _newsletterInputDecoration(icon: icon, hint: hint),
    );
  }
}

InputDecoration _newsletterInputDecoration({
  required IconData icon,
  required String hint,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13),
    prefixIcon: Icon(icon, color: Colors.black87, size: 21),
    prefixIconConstraints: const BoxConstraints(minWidth: 44),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.line),
    ),
  );
}
