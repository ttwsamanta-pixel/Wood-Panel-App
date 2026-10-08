import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
          height: 206,
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
        _HomeEventsHeader(onViewAll: () => context.push('/events')),
        _HomeEventsCarousel(events: data.events),
        const SizedBox(height: 22),
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
    return GestureDetector(
      onTap: () => context.push('/article/${article.id}'),
      child: Container(
        width: 224,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WPImage(url: article.imageUrl, height: 124, width: 224),
            const SizedBox(height: 8),
            WPTag(article.category),
            const SizedBox(height: 7),
            Text(
              article.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900, height: 1.16),
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
      height: 210,
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
    return GestureDetector(
      onTap: () => context.push('/video/${video.id}'),
      child: Container(
        width: 224,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                WPImage(url: video.thumbnailUrl, height: 124, width: 224),
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
            const SizedBox(height: 8),
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
      height: 286,
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

class _HomeEventsHeader extends StatelessWidget {
  const _HomeEventsHeader({required this.onViewAll});

  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontSize: 26,
                          height: 1.08,
                        ),
                    children: const [
                      TextSpan(text: 'Upcoming '),
                      TextSpan(
                        text: 'Events',
                        style: TextStyle(color: AppColors.copper),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onViewAll,
                iconAlignment: IconAlignment.end,
                label: const Text(
                  'View All',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: 28,
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.copper,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Explore global trade shows, exhibitions and industry events.',
            style: TextStyle(color: AppColors.muted, fontSize: 15),
          ),
        ],
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
    final dateParts = _eventDateParts(event.date);
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
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: const Color(0xFFF7F1EC),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: WPImage(
                          url: event.imageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    bottom: 14,
                    child: Container(
                      width: 74,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppColors.copper,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            dateParts.month,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            dateParts.day,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 7),
                          const Icon(Icons.calendar_month_rounded,
                              color: Colors.white, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 112,
              width: double.infinity,
              color: AppColors.green,
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          event.title.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 21,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          event.location,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            height: 1.22,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_forward_rounded,
                        color: AppColors.copper),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _EventDateParts _eventDateParts(String rawDate) {
    final upper = rawDate.toUpperCase();
    final monthMatch =
        RegExp(r'\b(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Z]*\b')
            .firstMatch(upper);
    final numbers = RegExp(r'\d{1,4}')
        .allMatches(rawDate)
        .map((match) => match.group(0) ?? '')
        .where((value) => value.isNotEmpty)
        .toList();
    final month = monthMatch?.group(1) ?? 'EVENT';
    final day = numbers.length >= 2
        ? '${numbers[0]}-${numbers[1]}'
        : (numbers.isNotEmpty ? numbers[0] : '');
    final parsedYear = numbers.lastWhere(
      (value) => value.length == 4,
      orElse: () => '',
    );
    final year =
        parsedYear.isNotEmpty ? parsedYear : DateTime.now().year.toString();
    return _EventDateParts(
        month, [day, year].where((part) => part.isNotEmpty).join('\n'));
  }
}

class _EventDateParts {
  const _EventDateParts(this.month, this.day);

  final String month;
  final String day;
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
        height: 306,
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
              flex: 58,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 8, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mail_outline_rounded,
                            color: AppColors.copper, size: 24),
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
                    const SizedBox(height: 14),
                    const Text(
                      'Stay Ahead in the\nWood & Panel\nIndustry',
                      maxLines: 4,
                      style: TextStyle(
                        color: AppColors.green,
                        fontSize: 23,
                        height: 1.04,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 9),
                    const Text(
                      'Get the latest news, events, magazine highlights and industry insights.',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF55504A),
                        fontSize: 13,
                        height: 1.22,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 45,
                      width: 188,
                      child: FilledButton.icon(
                        onPressed: onPressed,
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text(
                          'Subscribe Now',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.copper,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
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
              flex: 40,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: _NewsletterPhonePreview(
                      coverUrl: coverUrl,
                      width: 108,
                      height: 204,
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            const Color(0xFFFFF7EC).withValues(alpha: .55),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: .36),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.mail_outline_rounded,
                          color: Colors.white, size: 34),
                    ),
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
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 30, 22, 22),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Text(
                          'Join Our\nNewsletter',
                          style: TextStyle(
                            fontSize: 30,
                            height: 1.04,
                            color: AppColors.green,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 104,
                        height: 118,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              right: 0,
                              top: -12,
                              child: Transform.rotate(
                                angle: .12,
                                child: _NewsletterPhonePreview(
                                  coverUrl: widget.coverUrl,
                                  width: 74,
                                  height: 126,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              top: 40,
                              child: Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: .55),
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.mail_outline_rounded,
                                    color: Colors.white, size: 30),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Get the latest news, events, magazine highlights and industry insights.',
                    style: TextStyle(
                      color: Color(0xFF56504A),
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 22),
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
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
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
            top: 10,
            right: 10,
            child: IconButton.filled(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
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
    prefixIcon: Icon(icon, color: Colors.black87),
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
